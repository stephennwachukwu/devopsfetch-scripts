#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
	echo "Please run as root"
	exit 1
fi

# Install necessary dependencies
sudo apt-get update
sudo apt-get install -y net-tools nginx docker.io jq

# Copy the devops script to /usr/local/bin/ and Make devopsfetch executable
cp devopsfetch.sh /usr/local/bin/devopsfetch
chmod +x /usr/local/bin/devopsfetch

# Create systemd service
cat <<EOF | sudo tee /etc/systemd/system/devopsfetch.service
[Unit]
Description=DevOps Info Fetch Service
After=network.target

[Service]
ExecStart=/usr/local/bin/devopsfetch -t now now
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start the service
systemctl daemon-reload
systemctl enable devopsfetch.service
systemctl start devopsfetch.service

# Setup log rotation
cat <<EOF | sudo tee /etc/logrotate.d/devopsfetch
/var/log/devopsfetch.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
    postrotate
        systemctl reload devopsfetch.service > /dev/null 2>/dev/null || true
    endscript
}
EOF

echo "Voila!!! Installation completed successfully!"
