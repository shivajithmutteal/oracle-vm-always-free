#!/usr/bin/env bash
# Keeps running `terraform apply` on an interval until it succeeds.
#
# Terraform itself does NOT retry "out of host capacity" errors — a
# failed apply just exits. This script is the actual retry loop:
# it re-runs `terraform apply -auto-approve`, and if that fails
# (almost always because the shape is out of capacity right now),
# waits and tries again.
#
# Usage:
#   ./retry-apply.sh [interval_minutes] [max_attempts]
#
#   interval_minutes  How long to wait between attempts. Default: 15.
#   max_attempts       Give up after this many tries. Default: 0 (unlimited).
#
# Examples:
#   ./retry-apply.sh                # retry every 15 min, forever
#   ./retry-apply.sh 30              # retry every 30 min, forever
#   ./retry-apply.sh 15 20           # retry every 15 min, give up after 20 tries

set -uo pipefail

interval_minutes="${1:-15}"
max_attempts="${2:-0}"

attempt=0
while true; do
  attempt=$((attempt + 1))
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt ${attempt}: running terraform apply..."

  if terraform apply -auto-approve; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Success on attempt ${attempt}."
    exit 0
  fi

  if [ "${max_attempts}" -gt 0 ] && [ "${attempt}" -ge "${max_attempts}" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Reached max attempts (${max_attempts}) without success. Giving up."
    exit 1
  fi

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt ${attempt} failed (most likely out of capacity). Retrying in ${interval_minutes} minute(s)..."
  sleep "$((interval_minutes * 60))"
done
