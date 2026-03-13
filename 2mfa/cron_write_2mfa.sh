#!/usr/bin/env bash
set -x
set -euo pipefail

OUT_FILE="/tmp/2mfa.txt"

if [[ -z "${TOKEN_2MFA_TB1:-}" ]]; then
  exit 2
fi

secret="$(echo "$TOKEN_2MFA_TB1" | tr -d ' ')"

code="$(
  docker run --rm \
    -e script_name=tb-2ver.py \
    2mfaver1 generate_google_2fa_code "$secret" \
  | tr -d '[:space:]'
)"

if [[ ! "$code" =~ ^[0-9]{6}$ ]]; then
  exit 1
fi

tmp_file="$(mktemp)"
{
  tail -n 2 "$OUT_FILE" 2>/dev/null || true
  echo "$code"
} >"$tmp_file"
echo line29
chmod 600 "$tmp_file" 2>/dev/null || true
rm -f "$OUT_FILE"
mv "$tmp_file" "$OUT_FILE"
echo line33