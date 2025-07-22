#!/bin/bash
# Robust, unattended Phish stream auto-updater for MyTube
# Enterprise-grade: scheduled start, aggressive retry, logging, lockfile, self-healing, cleanup

set -euo pipefail
cd /var/www/mytube

LOG_DIR="/var/log/mytube"
LOG_FILE="$LOG_DIR/auto-stream-updater.log"
LOCK_FILE="/tmp/auto-stream-updater.lock"
MAX_FAILS=240  # 1 hour of retries at 15s intervals
RETRY_INTERVAL=15
STREAM_BASE="https://forbinaquarium.com/hls/ph"
SHOW_DATES=(250722 250723) # July 22, 23, 2025
START_HOUR_UTC=21 # 3:30pm MT = 21:30 UTC
START_MIN_UTC=30
API_URL="http://localhost:3000/api/switch-show"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Redirect all output to log
exec >> "$LOG_FILE" 2>&1

log() {
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"
}

# Lockfile mechanism to prevent multiple instances
acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local existing_pid=$(cat "$LOCK_FILE")
        if kill -0 "$existing_pid" 2>/dev/null; then
            log "Another instance ($existing_pid) is running. Exiting."
            exit 0
        else
            log "Stale lockfile found (PID: $existing_pid). Removing."
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"; log "Lock released. Exiting."' EXIT INT TERM
}

# System maintenance
cleanup_system() {
    log "Starting system cleanup"
    
    # Clean up old logs (keep 7 days)
    find "$LOG_DIR" -type f -name '*.log' -mtime +7 -delete 2>/dev/null || true
    
    # Clean up old stream segments (keep only last 50)
    find ./stream -name '*.ts' -type f | sort -V | head -n -50 | xargs rm -f 2>/dev/null || true
    
    # Kill any orphaned ffmpeg processes
    pkill -f 'ffmpeg.*output.m3u8' 2>/dev/null || true
    sleep 3
    
    # Check disk space (warn if < 1GB free)
    local free_space=$(df /var/www/mytube | awk 'NR==2 {print $4}')
    if [ "$free_space" -lt 1048576 ]; then
        log "WARNING: Low disk space: ${free_space}KB remaining"
    fi
    
    log "System cleanup completed"
}

# Health check for the web server
check_server_health() {
    local retries=3
    while [ $retries -gt 0 ]; do
        if curl -f -s "http://localhost:3000/" >/dev/null; then
            return 0
        fi
        log "Server health check failed. Retrying..."
        retries=$((retries - 1))
        sleep 5
    done
    
    log "CRITICAL: Web server not responding. Attempting restart."
    pm2 restart mytube-server || true
    sleep 10
    return 1
}

# Robust stream switching with verification
switch_stream() {
    local show_date=$1
    local url="$STREAM_BASE$show_date.m3u8"
    local retries=3
    
    while [ $retries -gt 0 ]; do
        log "Attempting to switch to $show_date (attempt: $((4-retries)))"
        
        # API call to switch stream
        local response=$(curl -s -w "%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -d "{\"showDate\":\"$show_date\"}" \
            "$API_URL" 2>/dev/null)
        
        local http_code=${response: -3}
        local body=${response%???}
        
        if [ "$http_code" = "200" ]; then
            log "✅ API switch successful: $body"
            
            # Wait for ffmpeg to start
            sleep 15
            
            # Verify ffmpeg is running with correct stream
            if pgrep -f "$show_date" >/dev/null; then
                log "✅ FFmpeg verified running for $show_date"
                
                # Verify stream output is being generated
                if [ -f "./stream/output.m3u8" ] && [ -s "./stream/output.m3u8" ]; then
                    log "✅ Stream output verified"
                    return 0
                else
                    log "⚠️ Stream output file missing or empty"
                fi
            else
                log "⚠️ FFmpeg not detected for $show_date"
            fi
        else
            log "❌ API call failed. HTTP: $http_code, Response: $body"
        fi
        
        retries=$((retries - 1))
        if [ $retries -gt 0 ]; then
            log "Retrying stream switch in 30 seconds..."
            sleep 30
        fi
    done
    
    log "❌ Failed to switch to $show_date after 3 attempts"
    return 1
}

# Wait for scheduled time
wait_for_showtime() {
    local show_date=$1
    
    while true; do
        local now_h=$(date -u +%H)
        local now_m=$(date -u +%M)
        local current_day=$(date -u +%y%m%d)
        local show_day=${show_date:2}
        
        # Only start checking on the correct day at the correct time
        if [ "$current_day" = "$show_day" ]; then
            if (( 10#$now_h > START_HOUR_UTC )) || { (( 10#$now_h == START_HOUR_UTC )) && (( 10#$now_m >= START_MIN_UTC )); }; then
                log "Show time reached for $show_date. Starting stream checks."
                return 0
            fi
        fi
        
        log "Waiting for show $show_date. Current: $current_day $now_h:$now_m UTC. Target: $show_day 21:30 UTC. Next check in 60s."
        sleep 60
    done
}

# Main execution
main() {
    log "===== MyTube Auto-Stream-Updater Started (PID: $$) ====="
    
    acquire_lock
    cleanup_system
    
    if ! check_server_health; then
        log "CRITICAL: Server health check failed. Aborting."
        exit 1
    fi
    
    for show in "${SHOW_DATES[@]}"; do
        log "Processing show: $show"
        
        wait_for_showtime "$show"
        
        local attempts=0
        local success=false
        
        while [ $attempts -lt $MAX_FAILS ] && [ "$success" = false ]; do
            local url="$STREAM_BASE$show.m3u8"
            
            # Check if stream is available
            if curl -f -s -I "$url" >/dev/null 2>&1; then
                log "🎸 Stream detected: $url"
                
                if switch_stream "$show"; then
                    log "🎉 Successfully switched to $show"
                    success=true
                    break
                else
                    log "Failed to switch to $show. Will retry."
                fi
            else
                log "Stream not yet available: $url (attempt $((attempts + 1))/$MAX_FAILS)"
            fi
            
            attempts=$((attempts + 1))
            sleep $RETRY_INTERVAL
        done
        
        if [ "$success" = false ]; then
            log "❌ FAILED: Could not switch to $show after $MAX_FAILS attempts"
        fi
    done
    
    # Final status report
    log "===== Final Status Report ====="
    ps aux | grep ffmpeg | grep -v grep || log "No FFmpeg processes running"
    if [ -f "./current-show.json" ]; then
        local current_show=$(cat current-show.json | grep 'showId' | cut -d'"' -f4 2>/dev/null || echo "unknown")
        log "Current show: $current_show"
    fi
    log "===== Auto-Stream-Updater Completed ====="
}

# Execute main function
main
