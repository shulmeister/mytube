#!/bin/bash

# MyTube FFmpeg Simple Script for Linux
# Converted from PowerShell for DigitalOcean deployment

STREAM_URL="https://forbinaquarium.com/streams/ph250720.m3u8"
OUTPUT_DIR="/var/www/mytube/stream"
PID_FILE="/var/www/mytube/ffmpeg.pid"
LOG_FILE="/var/www/mytube/logs/ffmpeg.log"

# Create directories if they don't exist
mkdir -p "$OUTPUT_DIR"
mkdir -p "/var/www/mytube/logs"

case "$1" in
    "start"|"restart")
        echo "Starting FFmpeg stream relay..."
        
        # Kill existing process if running
        if [ -f "$PID_FILE" ]; then
            OLD_PID=$(cat "$PID_FILE")
            if kill -0 "$OLD_PID" 2>/dev/null; then
                echo "Stopping existing FFmpeg process (PID: $OLD_PID)"
                kill "$OLD_PID"
                sleep 2
            fi
            rm -f "$PID_FILE"
        fi
        
        # Start new FFmpeg process
        ffmpeg -i "$STREAM_URL" \
            -c copy \
            -f hls \
            -hls_time 4 \
            -hls_list_size 10 \
            -hls_flags delete_segments \
            "$OUTPUT_DIR/output.m3u8" \
            >> "$LOG_FILE" 2>&1 &
        
        # Save PID
        echo $! > "$PID_FILE"
        echo "FFmpeg started with PID: $(cat $PID_FILE)"
        ;;
        
    "stop")
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if kill -0 "$PID" 2>/dev/null; then
                echo "Stopping FFmpeg process (PID: $PID)"
                kill "$PID"
                rm -f "$PID_FILE"
            else
                echo "FFmpeg not running"
                rm -f "$PID_FILE"
            fi
        else
            echo "No PID file found"
        fi
        ;;
        
    "status")
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if kill -0 "$PID" 2>/dev/null; then
                echo "FFmpeg is running (PID: $PID)"
                if [ -f "$OUTPUT_DIR/output.m3u8" ]; then
                    SIZE=$(stat -f%z "$OUTPUT_DIR/output.m3u8" 2>/dev/null || stat -c%s "$OUTPUT_DIR/output.m3u8" 2>/dev/null)
                    MODIFIED=$(stat -f%Sm "$OUTPUT_DIR/output.m3u8" 2>/dev/null || stat -c%y "$OUTPUT_DIR/output.m3u8" 2>/dev/null)
                    echo "Stream file exists: $SIZE bytes, modified: $MODIFIED"
                else
                    echo "Stream file not found"
                fi
            else
                echo "FFmpeg not running"
                rm -f "$PID_FILE"
            fi
        else
            echo "FFmpeg not running (no PID file)"
        fi
        ;;
        
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
