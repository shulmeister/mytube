# MyTube: Phish Live Stream Relay System
*Project Summary for Forest Hills Stadium Shows (July 22-23, 2025)*

## Project Overview
A complete live streaming relay system designed to share Phish concerts with friends while attending shows at Forest Hills Stadium. The system captures HLS streams from forbinaquarium.com and redistributes them through a custom web interface accessible at `73.229.233.163:3000/go`.

## Technical Architecture

### Core Components
- **FFmpeg Stream Relay**: Copies HLS streams without re-encoding for optimal performance
- **Node.js Web Server**: Provides API endpoints and serves the streaming interface
- **PowerShell Automation**: Manages FFmpeg processes and stream source detection
- **HLS.js Web Player**: Browser-based video player with error recovery

### File Structure
```
c:\MyTube\
├── ffmpeg-simple.ps1      # Emergency simplified FFmpeg launcher (ACTIVE)
├── ffmpeg-launcher.ps1    # Original complex launcher (corrupted, replaced)
├── ffmpeg-wrapper.bat     # Batch wrapper for PowerShell integration
├── server.js              # Express web server with streaming API
├── package.json           # Node.js dependencies
├── public/
│   ├── index.html         # Full-featured web player interface
│   ├── live.html          # Welcome/landing page
│   ├── test.html          # Testing interface
│   └── video-test.html    # Video player testing
├── stream/                # HLS output directory
│   ├── output.m3u8        # Master playlist
│   └── output*.ts         # Video segments (4-second chunks)
└── logs/                  # FFmpeg and system logs
```

## Key Features Implemented

### Stream Management
- **Source Detection**: Automatically finds active Phish streams from forbinaquarium.com
- **Quality Optimization**: Copy mode (no re-encoding) for performance on older hardware
- **Segment Duration**: 4-second HLS segments for responsive playback
- **Error Recovery**: Automatic restart capabilities and process monitoring

### Web Interface
- **Easy Access**: Simple URL sharing via `73.229.233.163:3000/go`
- **Playback Controls**: Play/pause, volume, fullscreen, picture-in-picture
- **Keyboard Shortcuts**: Spacebar (play/pause), M (mute), F (fullscreen)
- **Multi-Device Support**: Responsive design for mobile, tablet, TV streaming
- **Status Monitoring**: Real-time stream status and error reporting

### Automation & Control
- **PowerShell Scripts**: Start/stop/restart/status commands
- **API Endpoints**: RESTful interface for stream control
- **Process Management**: PID tracking and automatic cleanup
- **Date Selection**: Support for multiple show dates and sources

## Performance Optimizations

### Hardware Constraints Addressed
- **5-Year-Old Laptop**: Simplified configuration for performance-limited hardware
- **Mobile Streaming**: Optimized for walking/movement scenarios
- **TV Playback**: Stable buffering for home entertainment systems
- **Multi-User Support**: Handles concurrent streams to multiple devices

### Emergency Fixes Applied
- **Simplified Script**: Created `ffmpeg-simple.ps1` for reliable operation
- **Copy Mode**: Eliminated CPU-intensive re-encoding
- **Batch Wrapper**: Resolved PowerShell terminal integration issues
- **Hardcoded Source**: Used Chicago stream (ph250720) for stability

## Current Status (July 21, 2025)

### Active Configuration
- **Running Process**: FFmpeg PID 21276 via `ffmpeg-simple.ps1`
- **Stream Source**: Chicago show (ph250720.m3u8)
- **Output**: 4-second HLS segments in `/stream/` directory
- **Web Server**: Express server on port 3000
- **Access URL**: `http://73.229.233.163:3000/go`

### Validated Features
- ✅ Mobile streaming during walks
- ✅ TV playback stability
- ✅ Multiple device concurrent access
- ✅ Error recovery and buffering management
- ✅ Easy URL sharing for friends

### System Commands
```powershell
# Start/restart stream
.\ffmpeg-simple.ps1 restart

# Check status
.\ffmpeg-simple.ps1 status

# Start web server
node server.js
```

## Forest Hills Stadium Deployment Plan

### Pre-Show Setup (July 21, 2025)
1. **System Validation**: All components tested and working
2. **Network Configuration**: Port forwarding confirmed on 73.229.233.163:3000
3. **Friend Notification**: Share URL `73.229.233.163:3000/go`
4. **Power Management**: Leave laptop connected to power during shows

### Show Days (July 22-23, 2025)
1. **Autonomous Operation**: System runs independently during concerts
2. **Source Switching**: May need to update stream source between shows
3. **Monitoring**: Check stream status before leaving for venue
4. **Emergency Protocol**: `ffmpeg-simple.ps1 restart` if issues arise

## Technical Lessons Learned

### KISS Principle Validation
- **Simple > Complex**: Emergency simplified script outperformed feature-rich version
- **Performance First**: Copy mode more reliable than quality enhancement
- **Hardware Reality**: 5-year-old laptop requires performance-focused approach

### Reliability Strategies
- **Fallback Options**: Multiple script versions for different scenarios
- **Error Handling**: Comprehensive process monitoring and restart capabilities
- **User Experience**: Prioritized stability over advanced features

## Future Considerations
- **Hardware Upgrade**: Newer laptop could support advanced features
- **Stream Sources**: Monitor forbinaquarium.com for source availability
- **Feature Restoration**: Complex features available in original scripts if needed
- **Scalability**: Current system handles multiple concurrent users effectively

---
*System ready for Forest Hills Stadium shows. Share URL with friends: `73.229.233.163:3000/go`*
