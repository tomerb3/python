home MCP service - dockerized python

This folder contains a small MCP-like service that runs inside Docker on your home LAN.


==========================

on windows to open and use port of wsl2 run this powershell in admin : 

$var= wsl -d Ubuntu -e bash -c "/sbin/ip -o -4 addr list eth0"
Write-Host $var -ForegroundColor Green
$wsl_addr = $var.split()[6].split('/')[0]

netsh interface portproxy delete v4tov4 listenport=8089 listenaddress=0.0.0.0

netsh interface portproxy add v4tov4 listenport=8089 listenaddress=0.0.0.0 connectport=8089 connectaddress=$wsl_addr

==========================

### Features

- **Port:** default `8089` (configurable via `MCP_PORT` env var)
- **Healthcheck:** `GET /hb`
  - `{ "status": "ready" }` → service up, no running jobs
  - `{ "status": "running" }` → at least one job currently executing
- **Async jobs with IDs** (pattern B):
  - `POST /task` → returns `job_id`
  - `GET /status/{job_id}` → job status
  - `GET /result/{job_id}` → download result file when done

### Tasks

Currently supported task types (in `app.py`):

- `task1`
  - Sleeps 60 seconds
  - Writes `/data/file1.txt` with content: `tomer`
  - `/result/{job_id}` returns that file

- `task2`
  - Sleeps 60 seconds
  - Writes `/data/file2.txt` with content: `baum`
  - `/result/{job_id}` returns that file

All files are written under `/data` inside the container.

### Build & run with Docker

From this folder:

```bash
docker build -t home-mcp .

docker run -ti --rm \
  -p 8089:8089 \
  -v "$(pwd)/data:/data" \
  --name home-mcp \
  home-mcp
```

- The bind-mount `$(pwd)/data:/data` lets you see `file1.txt` / `file2.txt` on the host.

### Example calls (from another machine on LAN)

Assume the host running Docker has IP `192.168.0.10`.

**1. Healthcheck**

```bash
curl http://192.168.0.128:8089/hb
```

**2. Start task1** (sleep 60, create `file1.txt` with `tomer`):

```bash
JOB=$(curl -s -X POST \
  -H 'Content-Type: application/json' \
  -d '{"task_type": "task1"}' \
  http://192.168.0.10:8089/task | jq -r '.job_id')
```

**3. Poll status**

```bash
curl http://192.168.0.10:8089/status/$JOB
```

**4. Download result file when done**

```bash
curl -OJ http://192.168.0.10:8089/result/$JOB
```

Use `task_type: "task2"` for the `baum` file (`file2.txt`).

1 ye