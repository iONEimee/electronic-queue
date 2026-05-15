from sqlalchemy import Column, Integer, String, DateTime

class Ticket(Base):
    __tablename__ = 'tickets'
    id = Column(Integer, primary_key=True)
    number = Column(Integer)
    service_type = Column(String)
    created_at = Column(DateTime)
    status = Column(String)  # 'waiting', 'called', 'completed'

class Service(Base):
    __tablename__ = 'services'
    id = Column(Integer, primary_key=True)
    name = Column(String)
    prefix = Column(String)