-- Проект структуры PostgreSQL. Серверная миграция и испытания БД ещё не выполнены.
BEGIN;
CREATE TABLE service (
 id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 prefix varchar(4) NOT NULL UNIQUE,
 name varchar(100) NOT NULL,
 active boolean NOT NULL DEFAULT true
);
CREATE TABLE user_account (
 id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 login varchar(100) NOT NULL UNIQUE,
 password_hash text NOT NULL,
 role varchar(16) NOT NULL CHECK (role IN ('operator','admin')),
 active boolean NOT NULL DEFAULT true
);
CREATE TABLE service_window (
 id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 label varchar(40) NOT NULL,
 operator_id integer UNIQUE REFERENCES user_account(id),
 active boolean NOT NULL DEFAULT true
);
CREATE TABLE window_service (
 window_id integer NOT NULL REFERENCES service_window(id),
 service_id integer NOT NULL REFERENCES service(id),
 PRIMARY KEY(window_id,service_id)
);
CREATE TABLE daily_counter (
 service_id integer NOT NULL REFERENCES service(id),
 business_date date NOT NULL,
 last_value integer NOT NULL CHECK (last_value >= 0),
 PRIMARY KEY(service_id,business_date)
);
CREATE TABLE ticket (
 id uuid PRIMARY KEY,
 service_id integer NOT NULL REFERENCES service(id),
 window_id integer REFERENCES service_window(id),
 business_date date NOT NULL,
 seq_no integer NOT NULL CHECK (seq_no > 0),
 number varchar(32) NOT NULL,
 status varchar(16) NOT NULL CHECK (status IN ('waiting','called','in_service','completed','no_show','cancelled')),
 created_at timestamptz NOT NULL,
 called_at timestamptz,
 started_at timestamptz,
 finished_at timestamptz,
 version integer NOT NULL DEFAULT 1 CHECK (version > 0),
 owner_token_hash char(64) NOT NULL,
 UNIQUE(service_id,business_date,seq_no),
 CHECK (called_at IS NULL OR called_at >= created_at),
 CHECK (started_at IS NULL OR (called_at IS NOT NULL AND started_at >= called_at)),
 CHECK (finished_at IS NULL OR finished_at >= COALESCE(started_at,called_at,created_at)),
 CHECK (status NOT IN ('called','in_service','completed','no_show') OR (called_at IS NOT NULL AND window_id IS NOT NULL)),
 CHECK (status NOT IN ('in_service','completed') OR started_at IS NOT NULL),
 CHECK (status NOT IN ('completed','no_show','cancelled') OR finished_at IS NOT NULL),
 CHECK (status <> 'waiting' OR (called_at IS NULL AND started_at IS NULL AND finished_at IS NULL AND window_id IS NULL)),
 CHECK (status <> 'called' OR (started_at IS NULL AND finished_at IS NULL)),
 CHECK (status <> 'in_service' OR finished_at IS NULL),
 CHECK (status NOT IN ('cancelled','no_show') OR started_at IS NULL),
 CHECK (status <> 'cancelled' OR called_at IS NULL),
 CHECK (status <> 'no_show' OR finished_at >= called_at + interval '2 minutes')
);
CREATE UNIQUE INDEX one_active_ticket_per_window ON ticket(window_id)
 WHERE status IN ('called','in_service');
CREATE INDEX waiting_by_service_date ON ticket(service_id,business_date,created_at,id)
 WHERE status='waiting';
CREATE TABLE ticket_event (
 id uuid PRIMARY KEY,
 ticket_id uuid NOT NULL REFERENCES ticket(id),
 actor_user_id integer REFERENCES user_account(id),
 from_status varchar(16) CHECK (from_status IN ('waiting','called','in_service','completed','no_show','cancelled')),
 to_status varchar(16) NOT NULL CHECK (to_status IN ('waiting','called','in_service','completed','no_show','cancelled')),
 occurred_at timestamptz NOT NULL
);
CREATE INDEX ticket_event_history ON ticket_event(ticket_id,occurred_at,id);
CREATE TABLE idempotency_key (
 scope varchar(100) NOT NULL,
 token uuid NOT NULL,
 ticket_id uuid NOT NULL UNIQUE REFERENCES ticket(id),
 request_hash char(64) NOT NULL,
 created_at timestamptz NOT NULL,
 PRIMARY KEY(scope,token)
);
COMMIT;

-- Алгоритм выдачи (не исполняемый пример):
-- 1. BEGIN; проверить активность service, проверить ключ и request_hash.
-- 2. INSERT daily_counter ... ON CONFLICT DO NOTHING.
-- 3. SELECT daily_counter ... FOR UPDATE; повторно проверить ключ.
-- 4. Увеличить last_value; INSERT ticket + ticket_event + idempotency_key; COMMIT.
-- При гонке вставки ключа транзакция откатывается; новый запрос читает прежний ticket.
-- Нельзя обрабатывать IntegrityError продолжением уже прерванной транзакции.

-- Алгоритм вызова: BEGIN; SELECT service_window ... FOR UPDATE;
-- проверить назначение оператора, активность окна и отсутствие активного ticket;
-- выбрать waiting по допустимым услугам, дате, created_at,id FOR UPDATE OF ticket;
-- повторно проверить статус; UPDATE status='called' + INSERT ticket_event; COMMIT.
-- SKIP LOCKED не используется: он нарушил бы строгий FIFO.
-- При изменении состояния проверять expected_version и повышать version.
-- Допустимые переходы и роль проверяет приложение; DDL не заменяет эти проверки.
