# MyTube - Live Stream Relay Server

A Node.js application that proxies HLS video streams and provides a clean web interface for viewing live content.

## Current Working State ✅

**Last Updated:** July 25, 2025  
**Version:** 2.1  
**Status:** FULLY OPERATIONAL  

### Architecture Overview

- **Backend:** Node.js + Express server running on port 3000
- **Frontend:** Vanilla HTML/CSS/JS with Video.js player
- **Streaming:** HLS proxy that rewrites manifest URLs and proxies video segments
- **Deployment:** DigitalOcean droplet at `143.198.144.51`

### Key Components

1. **HLS Proxy Endpoints:**
   - `/api/stream/load-date/:dateStr` - Loads and rewrites HLS manifests
   - `/api/stream/proxy/:dateStr/:segmentFile` - Proxies video segments
   - `/api/shows` - Returns available show data
   - `/api/health` - Health check endpoint

2. **Security Configuration:**
   - **NO HELMET MIDDLEWARE** (causes CSP conflicts)
   - CORS enabled for all origins
   - No additional security headers

3. **Frontend Features:**
   - Video.js based player
   - Show selection dropdown
   - Stream status indicators
   - Responsive design

### Critical Configuration Notes

⚠️ **IMPORTANT:** Do not enable helmet or security middleware - it breaks the video player and HLS streaming.

### Deployment Setup

**Server Location:** `/var/www/mytube/`  
**Process Management:** `nohup node app/server.js > server.log 2>&1 &`  
**Git Repository:** `shulmeister/mytube` (main branch)

### Working Deployment Commands

```bash
# Update server
ssh root@143.198.144.51
cd /var/www/mytube
git pull
killall node
nohup node app/server.js > server.log 2>&1 &
```

### Troubleshooting

**Browser Security Policy Errors:** Clear browser cache or use incognito mode. The server sends clean headers.

**Stream Not Loading:** Check server logs at `/var/www/mytube/server.log`

**Health Check:** `curl http://143.198.144.51:3000/api/health`

---

## Development Setup

1. Clone repository
2. Copy `.env.example` to `.env` and configure
3. Install dependencies: `npm install`
4. Run locally: `npm start`

## File Structure

```
app/
├── server.js          # Main Express server
├── public/
│   ├── index.html     # Frontend interface
│   └── favicon.ico
├── shows.json         # Show data
└── package.json       # Dependencies
```

---

**DO NOT MODIFY SECURITY SETTINGS WITHOUT TESTING**
