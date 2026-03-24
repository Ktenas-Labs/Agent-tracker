from sqlalchemy.orm import Session

from app.models.core import Contact, ConversationLog, Brief, UnitAgentAssignment


class OperationsRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_contacts(self):
        return self.db.query(Contact).all()

    def list_contacts_for_user(self, user_id: str):
        return (
            self.db.query(Contact)
            .join(UnitAgentAssignment, UnitAgentAssignment.unit_id == Contact.reserve_unit_id)
            .filter(UnitAgentAssignment.user_id == user_id)
            .all()
        )

    def create_contact(self, **kwargs):
        obj = Contact(**kwargs)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def list_conversations(self):
        return self.db.query(ConversationLog).all()

    def list_conversations_for_user(self, user_id: str):
        return (
            self.db.query(ConversationLog)
            .join(UnitAgentAssignment, UnitAgentAssignment.unit_id == ConversationLog.reserve_unit_id)
            .filter(UnitAgentAssignment.user_id == user_id)
            .all()
        )

    def create_conversation(self, **kwargs):
        obj = ConversationLog(**kwargs)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def list_briefs(self):
        return self.db.query(Brief).all()

    def list_briefs_for_user(self, user_id: str):
        return (
            self.db.query(Brief)
            .join(UnitAgentAssignment, UnitAgentAssignment.unit_id == Brief.reserve_unit_id)
            .filter(UnitAgentAssignment.user_id == user_id)
            .all()
        )

    def create_brief(self, **kwargs):
        obj = Brief(**kwargs)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj
