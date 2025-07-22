#!/bin/bash
# Setup automatic stream updates for MyTube
# This will check every hour for new Phish streams

cd /var/www/mytube

echo "🎸 Setting up automatic stream updates..."

# Upload the auto updater script
chmod +x auto-stream-updater.sh

# Create a cron job that runs every hour
echo "⏰ Adding hourly cron job..."
(crontab -l 2>/dev/null; echo "0 * * * * cd /var/www/mytube && ./auto-stream-updater.sh >> logs/auto-update.log 2>&1") | crontab -

# Also add one that runs every 15 minutes during show times (7-11 PM ET)
echo "🎵 Adding frequent checks during show hours..."
(crontab -l 2>/dev/null; echo "*/15 19-23 * * * cd /var/www/mytube && ./auto-stream-updater.sh >> logs/auto-update.log 2>&1") | crontab -

# Show current cron jobs
echo "✅ Cron jobs installed:"
crontab -l

echo ""
echo "🎸 Auto-updater is now active!"
echo "📅 Will check for new streams:"
echo "   - Every hour (general check)"
echo "   - Every 15 minutes from 7-11 PM ET (show time)"
echo "📝 Logs: /var/www/mytube/logs/auto-update.log"

# Test it now
echo ""
echo "🧪 Testing auto-updater now..."
./auto-stream-updater.sh
