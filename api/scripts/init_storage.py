"""Crea el bucket (si no existe) y aplica la regla de ciclo de vida de tmp/.

Sirve igual para MinIO local (docker-compose lo corre solo) y para Cloudflare R2:
    S3_ENDPOINT_URL=https://<ACCOUNT_ID>.r2.cloudflarestorage.com S3_REGION=auto ... \
    python -m scripts.init_storage
"""

import logging
import sys
import time

from botocore.exceptions import BotoCoreError, ClientError

from app.core.config import StorageSettings
from app.services.storage import TMP_LIFECYCLE, build_s3_client

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("init_storage")


def main(retries: int = 30, delay_seconds: float = 2.0) -> int:
    settings = StorageSettings()
    client = build_s3_client(settings, endpoint_url=settings.s3_endpoint_url)
    bucket = settings.s3_bucket

    for attempt in range(1, retries + 1):
        try:
            client.list_buckets()
            break
        except (BotoCoreError, ClientError) as exc:
            logger.info("Esperando el almacenamiento (%s/%s): %s", attempt, retries, exc)
            time.sleep(delay_seconds)
    else:
        logger.error("El almacenamiento no respondió")
        return 1

    try:
        client.head_bucket(Bucket=bucket)
        logger.info("El bucket %s ya existe", bucket)
    except ClientError:
        client.create_bucket(Bucket=bucket)
        logger.info("Bucket %s creado", bucket)

    client.put_bucket_lifecycle_configuration(Bucket=bucket, LifecycleConfiguration=TMP_LIFECYCLE)
    rules = client.get_bucket_lifecycle_configuration(Bucket=bucket)["Rules"]
    logger.info("Ciclo de vida aplicado: %s", rules)
    return 0


if __name__ == "__main__":
    sys.exit(main())
