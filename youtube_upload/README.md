# YouTube MP4 Uploader (Python)

This small utility uploads an MP4 to YouTube using Application Default Credentials (ADC) and the YouTube Data API v3.

It is set up to work with Google Cloud SDK authentication performed inside a Docker container, as you requested.

## Contents

- `uploader.py` — Python script that performs a resumable upload.
- `requirements.txt` — Python dependencies.
- `auth_with_docker.sh` — Helper script to authenticate via the official gcloud Docker image and store ADC on your host.

## Prerequisites

- Python 3.9+ on your host.
- A Google account with access to upload videos on YouTube.
- YouTube Data API v3 enabled on the associated Google project (most accounts work with ADC + user consent flow).

## Authenticate using the gcloud Docker image

This uses the official Google Cloud SDK Docker image and binds your host's gcloud config directory so Application Default Credentials are written to your host at `~/.config/gcloud/application_default_credentials.json`.

Run:

```bash
./auth_with_docker.sh
```

What it does under the hood:

- Pulls `gcr.io/google.com/cloudsdktool/google-cloud-cli:stable`.
- Runs `gcloud auth application-default login` with the required YouTube scope.
- Persists credentials to your host in `~/.config/gcloud` via a bind mount.

If you prefer the exact one-liner similar to your snippet:

```bash
docker run -it --rm \
  -v "$HOME/.config/gcloud:/root/.config/gcloud" \
  gcr.io/google.com/cloudsdktool/google-cloud-cli:stable \
  gcloud auth application-default login \
  --scopes=https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/youtube.upload
```

Note: `gcloud auth login` alone is not sufficient for Application Default Credentials. Use `gcloud auth application-default login`.

## Install Python dependencies

From the `youtube_upload/` directory:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Upload a video

Example:

```bash
python uploader.py \
  --file /path/to/video.mp4 \
  --title "My Test Upload" \
  --description "Uploaded via API" \
  --tags "test,api,upload" \
  --privacyStatus unlisted
```

Options:

- `--file` (required): Path to the MP4 file.
- `--title`: Video title (default: "Test Upload").
- `--description`: Description text.
- `--tags`: Comma-separated list of tags.
- `--category`: YouTube category ID (default: 22 - People & Blogs).
- `--privacyStatus`: `public`, `private`, or `unlisted` (default: `unlisted`).
- `--madeForKids`: Include to mark as made for kids (COPPA).
- `--chunksize`: Chunk size in bytes for resumable upload (default: -1 lets the library choose). For very large files you may set e.g. `--chunksize 10485760` (10 MB).

On success, you'll see the uploaded `videoId` in JSON and a confirmation line. Example:

```json
{"status": "uploaded", "videoId": "abc123xyz"}
```

## If Google blocks the ADC login ("This app is blocked")

Some Google accounts/org policies block unverified apps or specific sensitive scopes during the ADC flow. In that case, use a first‑party OAuth client (Installed App / Desktop) and run the uploader with that client directly.

Steps:

1. Enable the API
   - Go to https://console.cloud.google.com/apis/library
   - Select your project (or create one) and enable "YouTube Data API v3".

2. Configure OAuth consent screen
   - Go to https://console.cloud.google.com/apis/credentials/consent
   - User type: External.
   - Add your email as a test user (and any others who will run the uploader).
   - You can leave publishing status in "Testing"; test users can proceed without full verification.

3. Create OAuth client (Desktop app)
   - Go to https://console.cloud.google.com/apis/credentials
   - Create credentials → OAuth client ID → Application type: Desktop app.
   - Download the JSON and save it as `client_secrets.json` under `youtube_upload/` (or another path).

4. Run the uploader with the client

```bash
python uploader.py \
  --client-secrets ./client_secrets.json \
  --file /path/to/video.mp4 \
  --title "My Test Upload" \
  --description "Uploaded via API" \
  --tags "tag1,tag2" \
  --privacyStatus unlisted
```

Notes:

- The script will cache user tokens at `~/.config/youtube_uploader/token.json` (configurable via `--credentials-file`).
- If you're on a headless machine, add `--no-browser` to use the console-based flow; paste the URL into a browser on any device.
- Service accounts are not supported for YouTube channel uploads. You must use a user OAuth flow tied to the channel.

## Troubleshooting

- If you receive 401/403 errors, re-run the auth command to ensure `application-default` credentials exist and include the `youtube.upload` scope.
- Ensure your Google account has permission to upload on the target YouTube channel. If you manage multiple channels, the browser consent screen during auth lets you pick the account/channel.
- If uploads hang or fail intermittently, try setting a smaller `--chunksize` (e.g., 10–20 MB) to improve resiliency.
