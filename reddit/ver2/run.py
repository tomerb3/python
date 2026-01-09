import praw
import json
import os
import random

import argparse

parser = argparse.ArgumentParser(description='Reddit subreddit scraper')
parser.add_argument('--subreddit', required=True, help='Subreddit name to scrape')
args = parser.parse_args()

# Log In to App:
reddit = praw.Reddit(client_id='3Guv0aII5JKSRmMLJZFxGQ', client_secret='Q9EW0_92G4tC5pyfztpib_MTF1AJZg', user_agent='Data Scraping')
subs = reddit.subreddit(args.subreddit).top(time_filter='week', limit=10)

submissions = list(subs)
if not submissions:
    print(json.dumps({"subreddit": args.subreddit, "thread": None, "comments": []}, ensure_ascii=True))
    raise SystemExit(0)

top_candidates = sorted(submissions, key=lambda s: s.score, reverse=True)[:5]
top_submission = random.choice(top_candidates)

top_submission.comments.replace_more(limit=0)

top_level_comments = list(top_submission.comments)
top_level_comments = sorted(top_level_comments, key=lambda c: c.score, reverse=True)[:10]

comments = []
for comment in top_level_comments:
    comments.append({
        "id": comment.id,
        "author": str(comment.author) if comment.author else None,
        "body": comment.body,
        "score": comment.score,
        "created_utc": comment.created_utc,
        "permalink": comment.permalink,
    })

thread = {
    "id": top_submission.id,
    "title": top_submission.title,
    "selftext": top_submission.selftext if hasattr(top_submission, 'selftext') else '',
    "url": top_submission.url,
    "permalink": top_submission.permalink,
    "score": top_submission.score,
    "num_comments": top_submission.num_comments,
    "created_utc": top_submission.created_utc,
}

obj = {
    "subreddit": args.subreddit,
    "thread": thread,
    "comments": comments,
}

output_path = os.environ.get("file")
if output_path:
    parent_dir = os.path.dirname(output_path)
    if parent_dir:
        os.makedirs(parent_dir, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=True)

print(json.dumps(obj, ensure_ascii=True))