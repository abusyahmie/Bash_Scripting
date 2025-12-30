#!/bin/bash

################################
# CONFIGURATION
################################

# HLS audio stream URL
STREAM_URL="https://ais-sa8.cdnstream1.com/5035/playlist.m3u8?aw_0_1st.playerid=IKIMFMAudioWeb"

# Duration of each recording (seconds)
DURATION=900   # 15 minutes

# Output directory for recordings
OUTDIR="$HOME/recordings"

# Log directory
LOGDIR="$HOME/recordings/logs"

# Delete recordings older than N days
RETENTION_DAYS=7

# Timeout for connectivity test (seconds)
CONNECT_TIMEOUT=8


################################
# SETUP DIRECTORIES
################################

mkdir -p "$OUTDIR"
mkdir -p "$LOGDIR"


################################
# CONNECTIVITY CHECK
################################

echo "$(date): Checking network availability..." >> "$LOGDIR/record.log"

# Wait for general internet connectivity before probing the stream.
# Configure these values if you need a longer wait or shorter retry interval.
NETWORK_WAIT_MAX=60       # total seconds to wait for internet
NETWORK_WAIT_INTERVAL=5   # seconds between checks
NETWORK_TEST_URL="https://www.apple.com"

elapsed=0
echo "$(date): Waiting for network connectivity (max ${NETWORK_WAIT_MAX}s)..." >> "$LOGDIR/record.log"
while ! curl --silent --head --fail --max-time 5 "$NETWORK_TEST_URL" > /dev/null 2>&1; do
  if [ "$elapsed" -ge "$NETWORK_WAIT_MAX" ]; then
    echo "$(date): Network unavailable after ${NETWORK_WAIT_MAX}s. Exiting." >> "$LOGDIR/record.log"
    exit 1
  fi
  sleep "$NETWORK_WAIT_INTERVAL"
  elapsed=$((elapsed + NETWORK_WAIT_INTERVAL))
done

echo "$(date): Network reachable. Checking stream availability..." >> "$LOGDIR/record.log"

curl --silent --fail --max-time "$CONNECT_TIMEOUT" "$STREAM_URL" > /dev/null
if [ $? -ne 0 ]; then
  echo "$(date): Stream unavailable. Skipping recording." >> "$LOGDIR/record.log"
  exit 1
fi

echo "$(date): Stream reachable. Starting recording." >> "$LOGDIR/record.log"


################################
# OUTPUT FILENAME
################################

OUTPUT_FILE="$OUTDIR/record_$(date +%Y%m%d_%H%M%S).mp4"


################################
# RUN RECORDING (PREVENT SLEEP)
################################

# Use 'caffeinate' to prevent system sleep during recording
# Note: Adjust the path to 'ffmpeg' if necessary

caffeinate -s /usr/local/bin/ffmpeg \
  -i "$STREAM_URL" \
  -t "$DURATION" \
  -c copy -bsf:a aac_adtstoasc \
  -f mp4 "$OUTPUT_FILE" \
  >> "$LOGDIR/ffmpeg.log" 2>&1

echo "$(date): Recording completed → $OUTPUT_FILE" >> "$LOGDIR/record.log"


################################
# RETENTION POLICY (DELETE OLD FILES)
################################

find "$OUTDIR" -name "*.mp4" -type f -mtime +"$RETENTION_DAYS" -print -delete \
  >> "$LOGDIR/cleanup.log" 2>&1

echo "$(date): Cleanup done." >> "$LOGDIR/record.log"
