from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.core.security import decode_token
from app.db.session import get_db
from app.models.core import User


def get_current_user(authorization: str | None = Header(default=None), db: Session = Depends(get_db)) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.replace("Bearer ", "", 1)
    try:
        payload = decode_token(token)
    except Exception as ex:
        raise HTTPException(status_code=401, detail="Invalid token") from ex
    user = db.query(User).filter(User.id == payload.get("sub")).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    if hasattr(user, "is_active") and not user.is_active:
        raise HTTPException(status_code=403, detail="User is inactive")
    return user


def require_roles(*roles: str):
    def _checker(user: User = Depends(get_current_user)) -> User:
        if user.role.value not in roles:
            raise HTTPException(status_code=403, detail="Forbidden")
        return user

    return _checker
