import logging

LOG_FORMAT = "%(asctime)s %(levelname)s %(name)s: %(message)s"


def configure_logging(level: str) -> None:
    root = logging.getLogger()
    # Si ya hay handlers (pytest, otro runner) no los pisamos.
    if not root.handlers:
        logging.basicConfig(format=LOG_FORMAT)
    logging.getLogger("app").setLevel(level.upper())
