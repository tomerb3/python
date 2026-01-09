import praw
import json

import argparse

parser = argparse.ArgumentParser(description='Reddit subreddit scraper')
parser.add_argument('--subreddit', required=True, help='Subreddit name to scrape')
args = parser.parse_args()

# Log In to App:
reddit = praw.Reddit(client_id='3Guv0aII5JKSRmMLJZFxGQ', client_secret='Q9EW0_92G4tC5pyfztpib_MTF1AJZg', user_agent='Data Scraping')
subs = reddit.subreddit(args.subreddit).top('week')

import random

results = []
for submission in subs:
    # Fetch top-level comments (limit to avoid huge output)
    submission.comments.replace_more(limit=0)
    comments = []
    for comment in submission.comments.list():
        comments.append({
            "author": str(comment.author) if comment.author else None,
            "body": comment.body,
            "score": comment.score
        })
    results.append({
        "title": submission.title,
        "description": submission.selftext if hasattr(submission, 'selftext') else '',
        "num_comments": submission.num_comments,
        "score": submission.score,
        "comments": comments
    })

# Take only the 7 with the highest score
results = sorted(results, key=lambda x: x["score"], reverse=True)[:7]
# Shuffle their order
random.shuffle(results)

for item in results:
    # Clean special characters from title
    clean_title = ''.join([c for c in item['title'] if 32 <= ord(c) <= 126])
    obj = {"title": clean_title, "num_comments": item["num_comments"], "score": item["score"]}
    print(json.dumps(obj, ensure_ascii=True))
    