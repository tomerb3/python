
 # AI Scary Stories Auto-Poster (n8n)

 This project is an **n8n automation** that generates short vertical videos for the niche **AI scary stories**, then posts them to:

 - **Instagram Reels**: **6 times per day**
 - **TikTok**: **3 times per day**

 Each video is ~**5 seconds**, built from **2 AI-generated images** (created by **FLUX**), with simple text overlays:

 - **Top black bar**: a *hook* line
 - **Bottom black bar**: `read caption`

 The workflow also writes metadata to a Google Sheet for traceability and reuse.

 ---

 ## What it produces

 - **Output video**: 9:16 vertical reel (MP4)
 - **Duration**: ~5 seconds
 - **Visuals**: 2 still images (pic1 → pic2) with a fast transition (or a simple cut)
 - **Text overlays**:
   - Top: `hook`
   - Bottom: `read caption`
 - **Caption**: scary story caption text (used as the IG/TikTok post caption)

 ---

 ## Data tracking (Google Sheet)

 Every generated post is recorded to a Google Sheet with the following columns:

 - **id**: unique ID for the generated post (timestamp/uuid)
 - **caption**: the story caption text
 - **hook**: the short hook line shown at the top
 - **prompt pic1**: prompt used to generate image 1 (FLUX)
 - **prompt pic2**: prompt used to generate image 2 (FLUX)

 Recommended additional columns (optional, but helpful):

 - `platform_ig_status`, `platform_tiktok_status` (posted/failed)
 - `ig_url`, `tiktok_url`
 - `render_path` or `video_url`
 - `error`

 ---

 ## High-level workflow (n8n)

 The automation runs on a schedule and executes roughly this pipeline:

 1. **Schedule trigger**
    - IG: run 6 times/day
    - TikTok: run 3 times/day
 2. **Generate content text**
    - Create:
      - `hook` (short, punchy)
      - `caption` (scary story)
      - `prompt pic1` and `prompt pic2` (image prompts)
 3. **Generate 2 images with FLUX**
    - Use `prompt pic1` → image1
    - Use `prompt pic2` → image2
 4. **Render a short vertical video**
    - Combine image1 + image2 into a ~5s 9:16 video
    - Add black bars (top/bottom)
    - Overlay text:
      - top text = hook
      - bottom text = `read caption`
 5. **Write a row into Google Sheets**
    - Store id/caption/hook/prompts
 6. **Post to platform**
    - Instagram Reels posting
    - TikTok posting
 7. **Log result + error handling**
    - Update sheet (optional)
    - Retry on transient errors

 ---

 ## Scheduling requirements

 - **Instagram**: 6 posts/day (suggested evenly spaced)
 - **TikTok**: 3 posts/day

 In n8n you can implement this with:

 - A **Cron** node per platform
 - Or a single Cron node + routing logic

 ---

 ## Configuration

 This automation typically needs credentials/tokens for:

 - **n8n** (self-hosted or cloud)
 - **Google Sheets API** (OAuth)
 - **FLUX image generation provider**
   - e.g. Replicate / HuggingFace / Fal / internal API (depends on your setup)
 - **Instagram posting**
 - **TikTok posting**

 Because posting methods vary (official APIs vs third-party tools), keep secrets in **n8n Credentials** and/or environment variables.

 Suggested environment variables (rename to match your actual workflow):

 - `GOOGLE_SHEETS_ID`
 - `GOOGLE_SHEET_TAB`
 - `FLUX_API_KEY`
 - `FLUX_MODEL`
 - `IG_*` (depends on posting method)
 - `TIKTOK_*` (depends on posting method)

 ---

 ## Rendering notes (video)

 Typical ffmpeg-style settings (implementation-specific):

 - **Canvas**: 1080x1920
 - **FPS**: 30
 - **Duration**: 5s total
 - **Audio**: optional (if you add music/ambience)
 - **Text safety**:
   - Keep hook short enough to fit on 1–2 lines
   - Use high-contrast text (white on black)

 ---

 ## Content guidelines (AI scary stories)

 To reduce repetition and improve retention:

 - Vary story structure (twist endings, "found footage", "last message", "rules", etc.)
 - Keep the hook **curiosity-based** and under ~10 words when possible
 - Avoid disallowed/unsafe content for platform policies

 ---

 ## Troubleshooting

 - **Images fail to generate**
   - Check FLUX provider limits / API key / prompt validity
 - **Video render fails**
   - Check ffmpeg availability (if you use it)
   - Ensure images are downloaded locally before render
 - **Posting fails**
   - Confirm platform auth/session is valid
   - Watch rate limits and spam/automation restrictions
 - **Google Sheets write fails**
   - Confirm OAuth token permissions and sheet/tab name

 ---

 ## Open questions (so I can finalize this README to your exact setup)

 Reply with these details and I’ll tighten the README (naming exact nodes/credentials and adding a “How to import workflow” section):

 - **IG posting method**: Official Meta Graph API, mobile automation, or another service?
 - **TikTok posting method**: Official API or third-party?
 - **FLUX provider**: Replicate / Fal / HuggingFace / local server?
 - **Render engine**: ffmpeg on host, a custom script, or a cloud video service?

