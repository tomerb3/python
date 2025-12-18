FROM python:3.10.14-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY scrape_wiki.py ./

ENTRYPOINT ["python", "scrape_wiki.py"]
