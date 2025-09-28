#!/usr/bin/env python3

import argparse
import json
import os
import random
import sys
import time
from typing import Optional

import google.auth
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow

# YouTube Data API v3 scope for uploading
YOUTUBE_UPLOAD_SCOPE = "https://www.googleapis.com/auth/youtube.upload"
API_SERVICE_NAME = "youtube"
API_VERSION = "v3"

# Retriable status codes and exceptions (from Google samples)
RETRIABLE_STATUS_CODES = [500, 502, 503, 504]

def get_credentials(args):
    """Obtain credentials for YouTube upload.

    Order of preference:
    1) If --client-secrets is provided, use OAuth Installed App flow and cache token in --credentials-file.
    2) Otherwise, use Application Default Credentials (ADC).
    """
    # Option 1: Explicit OAuth client for cases where ADC is blocked
    if args.client_secrets:
        token_path = os.path.expanduser(args.credentials_file) if args.credentials_file else None
        creds = None
        if token_path and os.path.exists(token_path):
            try:
                creds = Credentials.from_authorized_user_file(token_path, scopes=[YOUTUBE_UPLOAD_SCOPE])
            except Exception:
                creds = None
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                flow = InstalledAppFlow.from_client_secrets_file(os.path.expanduser(args.client_secrets), scopes=[YOUTUBE_UPLOAD_SCOPE])
                if args.no_browser:
                    creds = flow.run_console()
                else:
                    # Opens a local server and browser; fall back to console if that fails
                    try:
                        creds = flow.run_local_server(port=0)
                    except Exception:
                        creds = flow.run_console()
            if token_path:
                os.makedirs(os.path.dirname(token_path), exist_ok=True)
                with open(token_path, "w") as f:
                    f.write(creds.to_json())
        return creds

    # Option 2: ADC
    creds, _ = google.auth.default(scopes=[YOUTUBE_UPLOAD_SCOPE])
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
    return creds


def initialize_upload(youtube, options):
    body = {
        "snippet": {
            "title": options.title,
            "description": options.description,
            "tags": options.tags.split(",") if options.tags else None,
            "categoryId": options.category,
        },
        "status": {
            "privacyStatus": options.privacyStatus,
            "selfDeclaredMadeForKids": options.madeForKids,
        },
    }

    # Remove None fields
    body["snippet"] = {k: v for k, v in body["snippet"].items() if v is not None}

    media = MediaFileUpload(
        options.file,
        chunksize=options.chunksize,
        resumable=True,
        mimetype="video/mp4",
    )

    request = youtube.videos().insert(
        part=",".join(body.keys()),
        body=body,
        media_body=media,
    )

    return resumable_upload(request, options)


def resumable_upload(request, options):
    response = None
    error = None
    retry = 0
    max_retries = options.max_retries

    while response is None:
        try:
            status, response = request.next_chunk()
            if response is not None:
                if "id" in response:
                    video_id = response["id"]
                    print(json.dumps({"status": "uploaded", "videoId": video_id}))
                    return video_id
                else:
                    raise RuntimeError(f"Unexpected response: {response}")
        except HttpError as e:
            if e.resp.status in RETRIABLE_STATUS_CODES:
                error = f"A retriable HTTP error {e.resp.status} occurred: {e.content}"
            else:
                raise
        except (OSError, IOError) as e:
            error = f"A retriable error occurred: {e}"

        if error is not None:
            retry += 1
            if retry > max_retries:
                raise RuntimeError(f"No longer attempting to retry. Last error: {error}")

            sleep_seconds = random.random() * (2 ** retry)
            print(f"Retrying in {sleep_seconds:.1f} seconds after error: {error}")
            time.sleep(sleep_seconds)
            error = None

    return None


def build_youtube_client(args):
    creds = get_credentials(args)
    return build(API_SERVICE_NAME, API_VERSION, credentials=creds)


def positive_int(value: str) -> int:
    ivalue = int(value)
    if ivalue <= 0:
        raise argparse.ArgumentTypeError("Value must be a positive integer")
    return ivalue


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Upload an MP4 to YouTube using ADC credentials.")
    parser.add_argument("--file", required=True, help="Path to the MP4 file to upload")
    parser.add_argument("--title", default="Test Upload", help="Video title")
    parser.add_argument("--description", default="", help="Video description")
    parser.add_argument("--tags", default="", help="Comma-separated list of tags")
    parser.add_argument("--category", default="22", help="YouTube video category ID (default: 22 - People & Blogs)")
    parser.add_argument("--privacyStatus", choices=["public", "private", "unlisted"], default="unlisted", help="Video privacy status")
    parser.add_argument("--madeForKids", action="store_true", help="Mark video as made for kids")
    parser.add_argument("--chunksize", type=positive_int, default=-1, help="Chunk size in bytes for resumable upload. Use -1 for default.")
    parser.add_argument("--max-retries", type=int, default=10, help="Max number of retries for retriable errors")
    parser.add_argument("--client-secrets", default="", help="Path to OAuth client_secrets.json for Installed App flow (use if ADC is blocked)")
    parser.add_argument("--credentials-file", default=os.path.expanduser("~/.config/youtube_uploader/token.json"), help="Path to store/read cached OAuth user credentials JSON")
    parser.add_argument("--no-browser", action="store_true", help="Use console-based OAuth flow (no local browser)")
    return parser.parse_args(argv)



def main(argv=None):
    args = parse_args(argv)

    if not os.path.isfile(args.file):
        print(f"File not found: {args.file}", file=sys.stderr)
        return 1

    try:
        youtube = build_youtube_client(args)
        video_id = initialize_upload(youtube, args)
        print(f"Upload successful. Video ID: {video_id}")
        return 0
    except HttpError as e:
        print(f"An HTTP error {e.resp.status} occurred:\n{e.content}", file=sys.stderr)
        return 2
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())
