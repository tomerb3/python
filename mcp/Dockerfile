FROM python:3.11-slim

WORKDIR /app

# Install docker CLI so we can call `docker run` against the host daemon via mounted socket
RUN apt-get update && \
    apt-get install -y docker.io && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./

ENV MCP_PORT=8089
EXPOSE 8089

CMD ["python", "app.py"]
