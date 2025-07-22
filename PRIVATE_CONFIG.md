# 🔒 Private Configuration Setup

**This file contains sensitive information - DO NOT commit to public repositories**

## Quick Setup for Your Stream Source

1. **Copy the environment template:**
   ```bash
   cp .env.template .env
   ```

2. **Edit the .env file with your actual stream source:**
   ```bash
   nano .env
   ```

3. **Configure your actual stream URLs:**
   ```bash
   # Replace these with your real stream source:
   STREAM_SOURCE_BASE_URL=https://forbinaquarium.com/Live/00/ph
   STREAM_SOURCE_FORMAT=YYMMDD
   STREAM_SOURCE_FULL_FORMAT=${STREAM_SOURCE_BASE_URL}${DATE}/ph${DATE}_1080p.m3u8
   
   # Example: https://forbinaquarium.com/Live/00/ph250722/ph250722_1080p.m3u8
   ```

4. **Verify the configuration:**
   ```bash
   # Test that your source is reachable
   curl -I "https://forbinaquarium.com/Live/00/ph$(date +%y%m%d)/ph$(date +%y%m%d)_1080p.m3u8"
   ```

## Security Notes

- ✅ `.env` file is automatically ignored by git
- ✅ Stream source URLs never appear in public code
- ✅ Only you have access to the actual source configuration
- ⚠️ **NEVER** commit `.env` or this file to public repositories

## Deployment Notes

When deploying to your DigitalOcean droplet:

1. Use the quick-deploy script as normal
2. After deployment, SSH into your droplet and configure:
   ```bash
   cd /root/mytube/app
   cp .env.template .env
   nano .env  # Add your real stream source URLs
   sudo systemctl restart mytube
   ```

This keeps your stream source completely private while maintaining full functionality.
