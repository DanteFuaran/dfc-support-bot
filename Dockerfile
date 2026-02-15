FROM python:3.12-alpine

WORKDIR /opt/dfc-sb

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt \
    && find /usr/local -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

COPY ./bot ./bot
COPY ./run.py ./run.py
COPY ./scripts/docker-entrypoint.sh ./scripts/docker-entrypoint.sh

RUN chmod +x ./scripts/docker-entrypoint.sh

CMD ["./scripts/docker-entrypoint.sh"]
