# Псевдокод: генератор талонов
from datetime import datetime
import random

class TicketGenerator:
    def __init__(self, service_prefix):
        self.service_prefix = service_prefix
        self.counter = 0

    def generate_ticket(self):
        self.counter += 1
        number = f"{self.service_prefix}-{self.counter}"
        ticket = {
            "number": number,
            "timestamp": datetime.now(),
            "status": "waiting"
        }
  
        return ticket

    def get_current_number(self):
        return f"{self.service_prefix}-{self.counter}"