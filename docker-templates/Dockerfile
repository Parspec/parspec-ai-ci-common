FROM python:3.10-slim

# Build args (if you use them)
ARG OPENAI_API_KEY
ARG EXTRACT_TABLE_API_KEY
ARG AWS_REGION
ARG P0_CLASSIFICATION_ENDPOINT
ARG MODEL_S3_PATH

# Runtime env (CHANGED: PYTHONPATH to /app/src, APP_MODULE without 'src.')
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    OPENAI_API_KEY=$OPENAI_API_KEY \
    EXTRACT_TABLE_API_KEY=$EXTRACT_TABLE_API_KEY \
    AWS_REGION=$AWS_REGION \
    P0_CLASSIFICATION_ENDPOINT=$P0_CLASSIFICATION_ENDPOINT \
    MODEL_S3_PATH=$MODEL_S3_PATH \
    PYTHONPATH=/app/src \
    TEMP_DIR=/app/temp \
    APP_MODULE="fastapi_table_parsing:app"

WORKDIR /app

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libglib2.0-0 \
    poppler-utils \
    tesseract-ocr \
  && rm -rf /var/lib/apt/lists/*

# Temp dir
RUN mkdir -p /app/temp && chmod 777 /app/temp

# App code
COPY . /app/

# (Optional but helpful) Fail fast if imports aren’t resolvable
RUN python - <<'PY'
import importlib
importlib.import_module("api.routes")
importlib.import_module("fastapi_table_parsing")
print("✅ Import smoke test passed")
PY

# Shared package (must have pyproject.toml or setup.py)
RUN pip install -e /app/shared

# Python deps
RUN if [ -f "requirements.txt" ]; then pip install --no-cache-dir -r requirements.txt; fi

EXPOSE 8080

# For initial debugging, 1 worker shows errors clearly; change to 4 later
CMD ["sh", "-c", "uvicorn $APP_MODULE --host 0.0.0.0 --port 8080 --workers 1"]
