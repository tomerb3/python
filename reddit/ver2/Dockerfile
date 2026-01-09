# Use official Python 3 base image
FROM python:3

# Set work directory
WORKDIR /app

# Copy requirements.txt if present
COPY requirements.txt ./

# Install dependencies if requirements.txt exists
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi

# Copy all python scripts (adjust as needed)
COPY ./*.py ./

# Set the entrypoint to your main script (change main.py to your actual script)
ENTRYPOINT ["python", "run.py"]

