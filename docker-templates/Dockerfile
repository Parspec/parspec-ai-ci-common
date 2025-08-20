# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Define build arguments for environment variables
ARG OPENAI_API_KEY
ARG EXTRACT_TABLE_API_KEY
ARG AWS_REGION
ARG P0_CLASSIFICATION_ENDPOINT
ARG MODEL_S3_PATH
ARG APP_MODULE="src.fastapi_table_parsing:app"

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    OPENAI_API_KEY=$OPENAI_API_KEY \
    EXTRACT_TABLE_API_KEY=$EXTRACT_TABLE_API_KEY \
    AWS_REGION=$AWS_REGION \
    P0_CLASSIFICATION_ENDPOINT=$P0_CLASSIFICATION_ENDPOINT \
    MODEL_S3_PATH=$MODEL_S3_PATH

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libgl1-mesa-glx \
    libglib2.0-0 \
    poppler-utils \
    tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

# Create and set permissions for temp directories
RUN mkdir -p /app/temp
RUN chmod 777 /app/temp

# Copy the entire service directory (build context)
COPY . /app/

# Install shared package
RUN pip install -e /app/shared

# Install Python dependencies if requirements.txt exists
RUN if [ -f "requirements.txt" ]; then pip install --no-cache-dir -r requirements.txt; fi

# Set Python path
ENV PYTHONPATH=/app
ENV TEMP_DIR=/app/temp

# Expose port
EXPOSE 8080

# Command to run the application (configurable via APP_MODULE build arg)
CMD ["sh", "-c", "cd /app && uvicorn $APP_MODULE --host 0.0.0.0 --port 8080 --workers 4"]