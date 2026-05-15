# Управление очередью
class QueueManager:
    def __init__(self):
        self.queue = []  # список талонов в порядке ожидания

    def add_ticket(self, ticket):
        self.queue.append(ticket)

    def call_next(self):
        if self.queue:
            next_ticket = self.queue.pop(0)
            next_ticket['status'] = 'called'
            return next_ticket
        return None

    def get_queue_length(self):
        return len(self.queue)