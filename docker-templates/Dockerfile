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
    libgl1-mesa-dev \
    libglib2.0-0 \
    poppler-utils \
    tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

# Create and set permissions for temp directories
RUN mkdir -p /app/temp
RUN chmod 777 /app/temp

# Copy the entire service directory (build context)
COPY . /app/

# Install shared package if it exists
RUN if [ -d "/app/shared" ]; then pip install -e /app/shared; fi

# Install Python dependencies if requirements.txt exists
RUN if [ -f "requirements.txt" ]; then pip install --no-cache-dir -r requirements.txt; fi

# Set Python path
ENV PYTHONPATH=/app
ENV TEMP_DIR=/app/temp

# Expose port
EXPOSE 8080

# Command to run the application (will be overridden by build args or service-specific config)
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "4"]