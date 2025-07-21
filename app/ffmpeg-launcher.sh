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

# Function to get current Mountain Time date in YYMMDD format
get_date_string() {
    # Use Mountain Time (Denver timezone) instead of UTC
    # Try multiple methods to ensure it works in Docker containers
    if command -v gdate >/dev/null 2>&1; then
        # macOS with coreutils
        TZ=America/Denver gdate +"%y%m%d"
    elif [ -f /usr/share/zoneinfo/America/Denver ]; then
        # Linux with timezone data
        TZ=America/Denver date +"%y%m%d"
    else
        # Fallback: calculate manually (UTC-7 for MST, UTC-6 for MDT)
        # For now, assume MDT (UTC-6) during summer
        local utc_hour=$(date -u +"%H")
        local utc_date=$(date -u +"%y%m%d")
        
        # If it's before 6 AM UTC, it's still the previous day in Mountain Time
        if [ "$utc_hour" -lt 6 ]; then
            if command -v gdate >/dev/null 2>&1; then
                gdate -u -d "yesterday" +"%y%m%d"
            else
                date -u -d "yesterday" +"%y%m%d" 2>/dev/null || date -u -v-1d +"%y%m%d" 2>/dev/null || echo "$utc_date"
            fi
        else
            echo "$utc_date"
        fi
    fi
}

# Function to get fallback date (yesterday in Mountain Time) in YYMMDD format
get_fallback_date_string() {
    # Try multiple methods for getting yesterday in Mountain Time
    if command -v gdate >/dev/null 2>&1; then
        TZ=America/Denver gdate -d "yesterday" +"%y%m%d"
    elif [ -f /usr/share/zoneinfo/America/Denver ]; then
        TZ=America/Denver date -d "yesterday" +"%y%m%d" 2>/dev/null || TZ=America/Denver date -v-1d +"%y%m%d" 2>/dev/null
    else
        # Manual fallback
        local current_mt=$(get_date_string)
        if command -v gdate >/dev/null 2>&1; then
            gdate -d "$current_mt -1 day" +"%y%m%d" 2>/dev/null || echo "$current_mt"
        else
            date -d "yesterday" +"%y%m%d" 2>/dev/null || date -v-1d +"%y%m%d" 2>/dev/null || echo "$current_mt"
        fi
    fi
}

# Function to construct the stream URL with fallback
construct_url() {
    local date_str=$(get_date_string)
    local url="${BASE_URL}/ph${date_str}/ph${date_str}_1080p.m3u8"
    
    echo "$(date): Mountain Time date calculated as: $date_str" >> "$LOG_FILE"
    echo "$(date): Testing current date URL: $url" >> "$LOG_FILE"
    
    # Test if today's stream exists
    if curl -s --head --max-time 10 "$url" | head -n 1 | grep -q "200 OK"; then
        echo "$(date): Using current date stream: $url" >> "$LOG_FILE"
        echo "$url"
        return
    fi
    
    # Known Phish show dates for July 2025 (based on tour schedule)
    # Jul 18, 19, 20: United Center, Chicago
    # Jul 15, 16: TD Pavilion at The Mann, Philadelphia  
    # Jul 11, 12, 13: North Charleston Coliseum
    # Jul 9: Schottenstein Center, Columbus
    # Jul 3, 4, 5: Folsom Field, Boulder
    local known_show_dates=("250720" "250719" "250718" "250716" "250715" "250713" "250712" "250711" "250709" "250705" "250704" "250703")
    
    echo "$(date): Current date stream not available, checking known Phish show dates..." >> "$LOG_FILE"
    
    for show_date in "${known_show_dates[@]}"; do
        local test_url="${BASE_URL}/ph${show_date}/ph${show_date}_1080p.m3u8"
        echo "$(date): Testing known show date $show_date: $test_url" >> "$LOG_FILE"
        
        if curl -s --head --max-time 10 "$test_url" | head -n 1 | grep -q "200 OK"; then
            echo "$(date): Found available stream from show date $show_date: $test_url" >> "$LOG_FILE"
            echo "$test_url"
            return
        fi
    done
    
    # If no known show dates work, check the last 14 days as fallback
    echo "$(date): No known show dates available, checking recent dates..." >> "$LOG_FILE"
    
    for i in {1..14}; do
        local test_date
        if command -v gdate >/dev/null 2>&1; then
            # Use gdate if available (macOS with coreutils)
            test_date=$(TZ=America/Denver gdate -d "$i days ago" +"%y%m%d")
        else
            # Use date with different syntax for Linux
            test_date=$(TZ=America/Denver date -d "$i days ago" +"%y%m%d" 2>/dev/null || TZ=America/Denver date -v-${i}d +"%y%m%d" 2>/dev/null)
        fi
        
        local test_url="${BASE_URL}/ph${test_date}/ph${test_date}_1080p.m3u8"
        echo "$(date): Testing date $test_date ($i days ago): $test_url" >> "$LOG_FILE"
        
        if curl -s --head --max-time 10 "$test_url" | head -n 1 | grep -q "200 OK"; then
            echo "$(date): Found available stream from $i days ago: $test_url" >> "$LOG_FILE"
            echo "$test_url"
            return
        fi
    done
    
    echo "$(date): ERROR - No available streams found" >> "$LOG_FILE"
    echo "$url"  # Return today's URL as fallback even if not available
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
    
    # Test source URL accessibility with more detailed logging
    echo "$(date): Testing source URL accessibility..." >> "$LOG_FILE"
    local test_result=$(curl -s --head --max-time 10 "$source_url" | head -n 1)
    echo "$(date): Source URL test result: $test_result" >> "$LOG_FILE"
    
    if ! echo "$test_result" | grep -q "200 OK"; then
        echo "$(date): ERROR - Source URL not accessible: $source_url" >> "$LOG_FILE"
        echo "$(date): Curl response: $test_result" >> "$LOG_FILE"
        return 1
    fi
    
    # Clean up any existing segments
    rm -f "$OUTPUT_DIR"/*.ts "$OUTPUT_DIR"/*.m3u8
    
    echo "$(date): Starting FFmpeg process..." >> "$LOG_FILE"
    
    # Start FFmpeg in background with more robust settings
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
        -reconnect 1 \
        -reconnect_at_eof 1 \
        -reconnect_streamed 1 \
        -reconnect_delay_max 2 \
        "$OUTPUT_DIR/output.m3u8" \
        >> "$LOG_FILE" 2>&1 &
    
    local ffmpeg_pid=$!
    echo "$ffmpeg_pid" > "$PID_FILE"
    echo "$(date): FFmpeg started with PID: $ffmpeg_pid" >> "$LOG_FILE"
    
    # Give FFmpeg a moment to start and check if it's still running
    sleep 3
    if ! ps -p "$ffmpeg_pid" > /dev/null 2>&1; then
        echo "$(date): ERROR - FFmpeg failed to start or crashed immediately" >> "$LOG_FILE"
        rm -f "$PID_FILE"
        return 1
    fi
    
    echo "$(date): FFmpeg startup successful" >> "$LOG_FILE"
    return 0
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
