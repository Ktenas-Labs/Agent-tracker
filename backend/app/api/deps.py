from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.core.security import decode_token
from app.db.session import get_db
from app.models.core import User, UserRole

# Role hierarchy levels (document §7: director ≥ manager ≥ agent)
_ROLE_LEVEL: dict[str, int] = {
    UserRole.agent.value: 1,
    UserRole.manager.value: 2,
    UserRole.director.value: 3,
}


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
    return user


def require_roles(*roles: str):
    """
    Dependency that enforces role-based access.

    Rules:
      - is_admin users always pass (admin is orthogonal to the hierarchy).
      - The role hierarchy cascades: director satisfies "manager" and "agent"
        checks; manager satisfies "agent" checks.
      - Passing "admin" as a required role means only is_admin users are allowed
        (since "admin" is no longer a role value in the hierarchy).
    """
    def _checker(user: User = Depends(get_current_user)) -> User:
        # Admins bypass all role checks
        if user.is_admin:
            return user

        user_level = _ROLE_LEVEL.get(user.role.value, 0)
        for required in roles:
            required_level = _ROLE_LEVEL.get(required, 0)
            if user_level >= required_level:
                return user

        raise HTTPException(status_code=403, detail="Forbidden")

    return _checker
