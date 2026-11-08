"""Tareas de administración.

Asignar el rol de veterinario (validación clínica) a un usuario existente:

    python -m app.cli set-role --email veterinaria@ejemplo.com --role vet
    python -m app.cli set-role --uid dev:vet --role vet          # usuario de prueba

Con docker compose:  docker compose exec api python -m app.cli set-role ...
El usuario debe haber entrado a la app al menos una vez (así existe en la base de datos).
"""

import argparse
import sys

from sqlalchemy import select

from app.core.config import get_settings
from app.core.db import create_db_engine, create_session_factory
from app.models import User, UserRole


def set_role(email: str | None, uid: str | None, role: str) -> int:
    settings = get_settings()
    engine = create_db_engine(settings.database_url)
    with create_session_factory(engine)() as db:
        query = (
            select(User).where(User.email == email)
            if email
            else select(User).where(User.firebase_uid == uid)
        )
        users = db.scalars(query).all()
        if len(users) != 1:
            print(f"Se esperaba 1 usuario y se encontraron {len(users)}.", file=sys.stderr)
            return 1
        users[0].role = UserRole(role)
        db.commit()
        print(f"{users[0].email or users[0].firebase_uid}: rol {role}")
    engine.dispose()
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli")
    commands = parser.add_subparsers(dest="command", required=True)
    cmd = commands.add_parser("set-role", help="Cambiar el rol de un usuario")
    who = cmd.add_mutually_exclusive_group(required=True)
    who.add_argument("--email")
    who.add_argument("--uid", help="firebase_uid; en modo dev es dev:<usuario>")
    cmd.add_argument("--role", required=True, choices=[r.value for r in UserRole])
    args = parser.parse_args(argv)
    return set_role(args.email, args.uid, args.role)


if __name__ == "__main__":
    sys.exit(main())
