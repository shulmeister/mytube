#!/bin/bash

# FFmpeg Stream Launcher
# Automatically generates date-based URL and starts FFmpeg HLS relay

set -e

# Configuration
BASE_URL="https://forbinaquarium.com/Live/00"
OUTPUT_DIR="/app/stream"
LOG_FILE="/app/logs/ffmpeg.log"
PID_FILE="/app/ffmpeg.pid"

# Create necessary directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "/app/logs"

# Function to get current UTC date in YYMMDD format
get_date_string() {
    date -u +"%y%m%d"
}

# Function to construct the stream URL
construct_url() {
    local date_str=$(get_date_string)
    echo "${BASE_URL}/ph${date_str}/ph${date_str}_1080p.m3u8"
}

# Function to clean up old segments
cleanup_old_segments() {
    echo "$(date): Cleaning up old segments..." >> "$LOG_FILE"
    find "$OUTPUT_DIR" -name "*.ts" -mmin +10 -delete 2>/dev/null || true
}

# Function to check if FFmpeg is running
is_ffmpeg_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Function to stop FFmpeg
stop_ffmpeg() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "$(date): Stopping FFmpeg (PID: $pid)..." >> "$LOG_FILE"
            kill "$pid" 2>/dev/null || true
            sleep 2
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
    fi
}

# Function to start FFmpeg
start_ffmpeg() {
    local source_url=$(construct_url)
    echo "$(date): Starting FFmpeg with source: $source_url" >> "$LOG_FILE"
    
    # Clean up any existing segments
    rm -f "$OUTPUT_DIR"/*.ts "$OUTPUT_DIR"/*.m3u8
    
    # Start FFmpeg in background
    ffmpeg -y \
        -i "$source_url" \
        -c copy \
        -f hls \
        -hls_time 6 \
        -hls_list_size 10 \
        -hls_wrap 20 \
        -hls_delete_threshold 5 \
        -hls_flags delete_segments+append_list \
        -hls_segment_filename "$OUTPUT_DIR/segment_%03d.ts" \
        "$OUTPUT_DIR/output.m3u8" \
        >> "$LOG_FILE" 2>&1 &
    
    local ffmpeg_pid=$!
    echo "$ffmpeg_pid" > "$PID_FILE"
    echo "$(date): FFmpeg started with PID: $ffmpeg_pid" >> "$LOG_FILE"
}

# Function to restart FFmpeg
restart_ffmpeg() {
    echo "$(date): Restarting FFmpeg..." >> "$LOG_FILE"
    stop_ffmpeg
    sleep 3
    start_ffmpeg
}

# Main execution
case "${1:-start}" in
    "start")
        echo "$(date): Stream launcher starting..." >> "$LOG_FILE"
        if is_ffmpeg_running; then
            echo "$(date): FFmpeg is already running" >> "$LOG_FILE"
        else
            start_ffmpeg
        fi
        ;;
    "stop")
        echo "$(date): Stopping stream..." >> "$LOG_FILE"
        stop_ffmpeg
        ;;
    "restart")
        restart_ffmpeg
        ;;
    "status")
        if is_ffmpeg_running; then
            echo "FFmpeg is running (PID: $(cat $PID_FILE))"
        else
            echo "FFmpeg is not running"
        fi
        ;;
    "monitor")
        # Monitor mode - restart if crashed
        while true; do
            if ! is_ffmpeg_running; then
                echo "$(date): FFmpeg not running, restarting..." >> "$LOG_FILE"
                start_ffmpeg
            fi
            
            # Clean up old segments every 5 minutes
            cleanup_old_segments
            
            sleep 30
        done
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|monitor}"
        exit 1
        ;;
esac
