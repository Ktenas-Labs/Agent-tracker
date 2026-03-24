from sqlalchemy.orm import Session

from app.repositories.operations_repository import OperationsRepository


class OperationsService:
    def __init__(self, db: Session):
        self.repo = OperationsRepository(db)

    def list_contacts(self):
        return self.repo.list_contacts()

    def list_contacts_for_user(self, user_id: str):
        return self.repo.list_contacts_for_user(user_id)

    def create_contact(self, payload: dict):
        return self.repo.create_contact(**payload)

    def list_conversations(self):
        return self.repo.list_conversations()

    def list_conversations_for_user(self, user_id: str):
        return self.repo.list_conversations_for_user(user_id)

    def create_conversation(self, payload: dict):
        return self.repo.create_conversation(**payload)

    def list_briefs(self):
        return self.repo.list_briefs()

    def list_briefs_for_user(self, user_id: str):
        return self.repo.list_briefs_for_user(user_id)

    def create_brief(self, payload: dict):
        return self.repo.create_brief(**payload)
