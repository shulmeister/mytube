#!/bin/bash

# Auto Stream Monitor - Checks for new streams and switches automatically
# This script runs periodically to detect when new streams become available

LOG_FILE="/var/www/mytube/logs/monitor.log"
BASE_URL="https://forbinaquarium.com/Live/00"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

echo "$(date): Auto stream monitor started" >> "$LOG_FILE"

# Function to check if a stream URL is available
check_stream_url() {
    local date_code="$1"
    local url="${BASE_URL}/ph${date_code}/ph${date_code}_1080p.m3u8"
    
    if curl -s --head --max-time 10 "$url" | head -n 1 | grep -q "200 OK"; then
        echo "$(date): Stream available: $url" >> "$LOG_FILE"
        return 0
    else
        echo "$(date): Stream not yet available: $url" >> "$LOG_FILE"
        return 1
    fi
}

# Function to get current Mountain Time date
get_current_mt_date() {
    if command -v gdate >/dev/null 2>&1; then
        TZ=America/Denver gdate +"%y%m%d"
    else
        TZ=America/Denver date +"%y%m%d"
    fi
}

# Function to restart stream with specific date
restart_stream_for_date() {
    local date_code="$1"
    echo "$(date): Switching to stream: $date_code" >> "$LOG_FILE"
    
    # Set environment variable and restart
    export FORCE_SHOW_DATE="$date_code"
    cd /var/www/mytube
    
    # Kill existing FFmpeg processes
    pkill -f ffmpeg
    
    # Start new stream with forced date
    nohup bash ffmpeg-launcher.sh start > /dev/null 2>&1 &
    
    echo "$(date): Stream switch initiated for $date_code" >> "$LOG_FILE"
}

# Main monitoring logic
main() {
    local current_date=$(get_current_mt_date)
    echo "$(date): Current Mountain Time date: $current_date" >> "$LOG_FILE"
    
    # Priority dates to check (upcoming shows)
    local priority_dates=("250723" "250722")
    
    for check_date in "${priority_dates[@]}"; do
        echo "$(date): Checking priority date: $check_date" >> "$LOG_FILE"
        
        if check_stream_url "$check_date"; then
            # Stream is available, check if we're already using it
            if ps aux | grep -v grep | grep -q "ph${check_date}"; then
                echo "$(date): Already streaming $check_date" >> "$LOG_FILE"
            else
                echo "$(date): New stream available: $check_date - switching!" >> "$LOG_FILE"
                restart_stream_for_date "$check_date"
                exit 0
            fi
        fi
    done
    
    # If we reach here, check if current date stream is available
    if [ "$current_date" != "250722" ] && [ "$current_date" != "250723" ]; then
        if check_stream_url "$current_date"; then
            if ! ps aux | grep -v grep | grep -q "ph${current_date}"; then
                echo "$(date): Current date stream available: $current_date - switching!" >> "$LOG_FILE"
                restart_stream_for_date "$current_date"
            fi
        fi
    fi
    
    echo "$(date): Monitor check complete" >> "$LOG_FILE"
}

# Run the main function
main
