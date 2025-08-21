FROM python:3.10-slim

# (Optional) build-time args – consider injecting secrets at runtime instead
ARG OPENAI_API_KEY
ARG EXTRACT_TABLE_API_KEY
ARG AWS_REGION
ARG P0_CLASSIFICATION_ENDPOINT
ARG MODEL_S3_PATH

# Runtime env
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    OPENAI_API_KEY=$OPENAI_API_KEY \
    EXTRACT_TABLE_API_KEY=$EXTRACT_TABLE_API_KEY \
    AWS_REGION=$AWS_REGION \
    P0_CLASSIFICATION_ENDPOINT=$P0_CLASSIFICATION_ENDPOINT \
    MODEL_S3_PATH=$MODEL_S3_PATH \
    PYTHONPATH=/app/src:/app/shared \
    TEMP_DIR=/app/temp \
    APP_MODULE="fastapi_table_parsing:app"

WORKDIR /app

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libgl1-mesa-glx \
    libglib2.0-0 \
    poppler-utils \
    tesseract-ocr \
  && rm -rf /var/lib/apt/lists/*

# App code (CI build context = services/table-parsing-service)
COPY . /app/

# If shared is a real package (pyproject.toml/setup.py), install it; otherwise it’s importable via PYTHONPATH
RUN pip install -e /app/shared || true

# Python deps – ensure requirements.txt includes: fastapi, uvicorn[standard], pydantic
RUN if [ -f "requirements.txt" ]; then pip install --no-cache-dir -r requirements.txt; else echo "No requirements.txt found"; fi

# (Optional) Smoke test AFTER deps are installed
# Comment out this block if it still triggers import-time side effects during build
RUN python - <<'PY'
import importlib
importlib.import_module("api.routes")
importlib.import_module("fastapi_table_parsing")
print("✅ Import smoke test passed")
PY

EXPOSE 8080

# Start app; use 1 worker while stabilizing; bump when ready
CMD ["sh", "-c", "uvicorn $APP_MODULE --host 0.0.0.0 --port 8080 --workers 1"]
