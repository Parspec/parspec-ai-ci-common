# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

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

# Copy parspec-shared package
COPY shared /app/shared/

# Install parspec-shared
RUN pip install -e /app/shared

# Copy requirements first to leverage Docker cache
COPY services/column-detection-service/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY services/column-detection-service/src/ /app/src/
COPY .env /app/.env

# Set Python path
ENV PYTHONPATH=/app/src
ENV TEMP_DIR=/app/temp

# Expose port
EXPOSE 8080

# Command to run the application
CMD ["uvicorn", "src.fastapi_column_detection:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "4"]