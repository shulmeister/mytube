#!/bin/bash
# Script to check server status on droplet

echo "Checking Node.js processes..."
ssh root@143.198.144.51 "ps aux | grep node"

echo "Checking if port 3000 is listening..."
ssh root@143.198.144.51 "netstat -tlnp | grep :3000"

echo "Checking myTube directory..."
ssh root@143.198.144.51 "ls -la /root/myTube/"

echo "Checking server logs..."
ssh root@143.198.144.51 "cd /root/myTube && pm2 logs"
