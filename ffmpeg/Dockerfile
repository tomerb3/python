# Minimal image with ffmpeg + tools needed by the scripts
FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC

# ffmpeg (includes ffprobe), bash, core tools, fonts (DejaVu), and tini as init
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ffmpeg \
      bash \
      coreutils \
      findutils \
      procps \
      ca-certificates \
      fontconfig \
      fonts-dejavu \
      locales \
      jq \
      tini \
      gawk && \
    update-alternatives --install /usr/bin/awk awk /usr/bin/gawk 10 && \
    rm -rf /var/lib/apt/lists/*

# UTF-8 locale (for drawtext and file parsing reliability)
RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Create working dirs commonly used by the scripts
RUN mkdir -p /app /data /tmp/a/fonts
WORKDIR /app

# Reasonable defaults; can be overridden with -e at runtime
ENV output_folder=/data \
    backup_folder=/data \
    font_folder=/data/fonts \
    back_before_video=none \
    back_45_video=back-45_m0.mp4

# Use tini as PID 1 for proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash"]
