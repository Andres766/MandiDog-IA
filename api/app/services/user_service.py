from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.core.auth import Principal
from app.models import User


def get_or_create_user(db: Session, principal: Principal) -> User:
    """El usuario se crea en la primera petición autenticada (no hay registro aparte)."""
    user = db.scalar(select(User).where(User.firebase_uid == principal.firebase_uid))
    if user is None:
        db.execute(
            insert(User)
            .values(
                firebase_uid=principal.firebase_uid,
                email=principal.email,
                display_name=principal.display_name,
            )
            .on_conflict_do_nothing(index_elements=[User.firebase_uid])
        )
        db.commit()
        user = db.scalar(select(User).where(User.firebase_uid == principal.firebase_uid))
        assert user is not None
    elif principal.email and principal.email != user.email:
        user.email = principal.email
        db.commit()
    return user
