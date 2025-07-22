#!/bin/bash
# ffmpeg-manager.sh - Linux-native FFmpeg process manager for Phish stream relay

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGS_DIR="$SCRIPT_DIR/logs"
STREAM_DIR="$SCRIPT_DIR/stream"
PID_FILE="$LOGS_DIR/ffmpeg.pid"
LOG_FILE="$LOGS_DIR/ffmpeg.log"

# Ensure directories exist
mkdir -p "$LOGS_DIR" "$STREAM_DIR"

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if FFmpeg process is running
is_ffmpeg_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0  # Running
        else
            log_message "Stale PID file found. Cleaning up."
            rm -f "$PID_FILE"
        fi
    fi
    return 1  # Not running
}

# Stop FFmpeg process
stop_ffmpeg() {
    log_message "Stopping FFmpeg process..."
    
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_message "Terminating FFmpeg process with PID: $pid"
            kill "$pid"
            
            # Wait for graceful shutdown
            for i in {1..10}; do
                if ! ps -p "$pid" > /dev/null 2>&1; then
                    log_message "FFmpeg process stopped gracefully."
                    break
                fi
                sleep 1
            done
            
            # Force kill if still running
            if ps -p "$pid" > /dev/null 2>&1; then
                log_message "Force killing FFmpeg process..."
                kill -9 "$pid"
            fi
        fi
        rm -f "$PID_FILE"
    fi
    
    # Kill any remaining ffmpeg processes related to this project
    pkill -f "ffmpeg.*mytube" 2>/dev/null || true
    log_message "FFmpeg stop operation completed."
}

# Start FFmpeg process
start_ffmpeg() {
    local date_code="$1"
    
    if [[ -z "$date_code" ]]; then
        log_message "ERROR: No date code provided for FFmpeg start"
        exit 1
    fi
    
    if is_ffmpeg_running; then
        log_message "ERROR: FFmpeg is already running. Stop it first."
        exit 1
    fi
    
    # Clean old stream files
    log_message "Cleaning old stream files..."
    rm -f "$STREAM_DIR"/*.ts "$STREAM_DIR"/*.m3u8
    
    # Construct stream URL
    local stream_url="https://forbinaquarium.com/Live/00/ph${date_code}/ph${date_code}_1080p.m3u8"
    log_message "Starting FFmpeg for date: $date_code"
    log_message "Stream URL: $stream_url"
    
    # Start FFmpeg with robust settings
    nohup ffmpeg \
        -fflags +genpts+discardcorrupt \
        -reconnect 1 \
        -reconnect_streamed 1 \
        -reconnect_delay_max 2 \
        -rw_timeout 3000000 \
        -timeout 3000000 \
        -i "$stream_url" \
        -c copy \
        -f hls \
        -hls_time 4 \
        -hls_list_size 10 \
        -hls_flags delete_segments \
        -hls_segment_filename "$STREAM_DIR/output%03d.ts" \
        "$STREAM_DIR/output.m3u8" \
        >> "$LOG_FILE" 2>&1 &
    
    # Capture PID
    local ffmpeg_pid=$!
    echo "$ffmpeg_pid" > "$PID_FILE"
    
    log_message "FFmpeg started with PID: $ffmpeg_pid"
    
    # Verify it's actually running
    sleep 2
    if ! ps -p "$ffmpeg_pid" > /dev/null 2>&1; then
        log_message "ERROR: FFmpeg failed to start or crashed immediately"
        rm -f "$PID_FILE"
        exit 1
    fi
    
    log_message "FFmpeg successfully started and verified running"
}

# Restart FFmpeg process
restart_ffmpeg() {
    local date_code="$1"
    
    log_message "=== RESTART REQUEST FOR DATE: $date_code ==="
    stop_ffmpeg
    sleep 2
    start_ffmpeg "$date_code"
    log_message "=== RESTART COMPLETED ==="
}

# Show status
show_status() {
    if is_ffmpeg_running; then
        local pid=$(cat "$PID_FILE")
        echo "FFmpeg is RUNNING with PID: $pid"
        log_message "Status check: FFmpeg running with PID $pid"
    else
        echo "FFmpeg is STOPPED"
        log_message "Status check: FFmpeg not running"
    fi
}

# Main script logic
case "$1" in
    start)
        if [[ -z "$2" ]]; then
            echo "Usage: $0 start <date_code>"
            echo "Example: $0 start 250722"
            exit 1
        fi
        start_ffmpeg "$2"
        ;;
    stop)
        stop_ffmpeg
        ;;
    restart)
        if [[ -z "$2" ]]; then
            echo "Usage: $0 restart <date_code>"
            echo "Example: $0 restart 250722"
            exit 1
        fi
        restart_ffmpeg "$2"
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status} [date_code]"
        echo ""
        echo "Commands:"
        echo "  start <date_code>   - Start FFmpeg with specified date"
        echo "  stop               - Stop FFmpeg process"
        echo "  restart <date_code> - Restart FFmpeg with specified date"
        echo "  status             - Show current status"
        echo ""
        echo "Date codes should be in YYMMDD format (e.g., 250722 for July 22, 2025)"
        exit 1
        ;;
esac

exit 0
