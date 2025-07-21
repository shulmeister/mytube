#!/bin/bash

# Stream monitoring and management script

set -e

LOG_FILE="/app/logs/monitor.log"
FFMPEG_SCRIPT="/app/ffmpeg-launcher.sh"

# Create logs directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log with timestamp
log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Function to check stream health
check_stream_health() {
    local manifest_file="/app/stream/output.m3u8"
    
    if [ -f "$manifest_file" ]; then
        local last_modified=$(stat -c %Y "$manifest_file" 2>/dev/null || stat -f %m "$manifest_file" 2>/dev/null)
        local current_time=$(date +%s)
        local age=$((current_time - last_modified))
        
        # If manifest is older than 60 seconds, consider it stale
        if [ $age -gt 60 ]; then
            return 1
        else
            return 0
        fi
    else
        return 1
    fi
}

# Function to check if web server is responding
check_web_server() {
    curl -f -s http://localhost:3000/health > /dev/null 2>&1
}

# Function to restart stream
restart_stream() {
    log "Restarting stream due to health check failure"
    $FFMPEG_SCRIPT restart
    sleep 10
}

# Function to send alert (customize as needed)
send_alert() {
    local message="$1"
    log "ALERT: $message"
    
    # Add your alerting logic here:
    # - Send email
    # - Post to Slack/Discord
    # - Write to external monitoring service
    # Example:
    # curl -X POST https://hooks.slack.com/your-webhook -d "{\"text\":\"$message\"}"
}

# Main monitoring loop
monitor() {
    log "Starting stream monitor"
    
    local consecutive_failures=0
    local max_failures=3
    
    while true; do
        if check_stream_health && check_web_server; then
            if [ $consecutive_failures -gt 0 ]; then
                log "Stream recovered after $consecutive_failures failures"
                send_alert "Stream relay recovered - back online"
            fi
            consecutive_failures=0
        else
            consecutive_failures=$((consecutive_failures + 1))
            log "Health check failed (attempt $consecutive_failures/$max_failures)"
            
            if [ $consecutive_failures -ge $max_failures ]; then
                send_alert "Stream relay is down - attempting restart"
                restart_stream
                consecutive_failures=0
            fi
        fi
        
        sleep 30
    done
}

# Function to show status
show_status() {
    echo "=== Stream Relay Status ==="
    echo ""
    
    # Check FFmpeg
    if $FFMPEG_SCRIPT status | grep -q "running"; then
        echo "✅ FFmpeg: Running"
    else
        echo "❌ FFmpeg: Not running"
    fi
    
    # Check web server
    if check_web_server; then
        echo "✅ Web Server: Running"
    else
        echo "❌ Web Server: Not responding"
    fi
    
    # Check stream health
    if check_stream_health; then
        echo "✅ Stream: Healthy"
    else
        echo "❌ Stream: Unhealthy or stale"
    fi
    
    # Show recent logs
    echo ""
    echo "=== Recent Log Entries ==="
    if [ -f "$LOG_FILE" ]; then
        tail -10 "$LOG_FILE"
    else
        echo "No log file found"
    fi
    
    # Show stream files
    echo ""
    echo "=== Stream Files ==="
    if [ -d "/app/stream" ]; then
        ls -la /app/stream/ | head -10
    else
        echo "Stream directory not found"
    fi
}

# Function to cleanup old logs
cleanup_logs() {
    log "Cleaning up old log files"
    
    # Keep only last 100MB of logs
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null) -gt 104857600 ]; then
        tail -n 10000 "$LOG_FILE" > "$LOG_FILE.tmp"
        mv "$LOG_FILE.tmp" "$LOG_FILE"
        log "Log file rotated"
    fi
    
    # Clean up old FFmpeg logs
    find /app/logs -name "*.log" -size +50M -exec truncate -s 0 {} \;
}

# Main script logic
case "${1:-status}" in
    "monitor")
        monitor
        ;;
    "status")
        show_status
        ;;
    "cleanup")
        cleanup_logs
        ;;
    "restart")
        restart_stream
        ;;
    "alert-test")
        send_alert "Test alert from stream monitor"
        ;;
    *)
        echo "Usage: $0 {monitor|status|cleanup|restart|alert-test}"
        echo ""
        echo "Commands:"
        echo "  monitor     - Start continuous monitoring (use in production)"
        echo "  status      - Show current status"
        echo "  cleanup     - Clean up old log files"
        echo "  restart     - Force restart the stream"
        echo "  alert-test  - Test alert functionality"
        exit 1
        ;;
esac
