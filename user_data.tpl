#!/bin/bash
set -e

# Log file for debugging
LOG_FILE="/var/log/user_data.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== User Data Started at $(date) ==="

# Update package cache and install nginx
echo "Installing nginx..."
dnf update -y
dnf install -y nginx

# Start and enable nginx
echo "Starting nginx..."
systemctl start nginx
systemctl enable nginx

# Wait for nginx to be fully started
echo "Waiting for nginx to start..."
for i in {1..10}; do
    if systemctl is-active --quiet nginx; then
        echo "nginx is running!"
        break
    fi
    echo "Waiting... ($i/10)"
    sleep 2
done

# Verify nginx is running
echo "Checking nginx status..."
systemctl status nginx

# Verify nginx is responding
echo "Testing HTTP response..."
curl -s -o /dev/null -w "%%{http_code}" http://localhost:80 || echo "curl failed"

echo "=== User Data Completed at $(date) ==="