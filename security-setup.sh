#!/bin/bash

# Security Hardening Script for VPS
# This script installs and configures security tools

set -e

echo "🔒 Installing security tools..."

# Update package list
apt update

# Install security packages
apt install -y \
    apparmor \
    apparmor-utils \
    fail2ban \
    ufw \
    clamav \
    clamav-daemon \
    rkhunter \
    chkrootkit \
    auditd \
    audispd-plugins \
    prometheus \
    prometheus-node-exporter

# Configure Docker security
echo "🐳 Configuring Docker security..."
cat > /etc/docker/daemon.json << 'EOF'
{
  "icc": false,
  "userns-remap": "default",
  "no-new-privileges": true,
  "live-restore": true,
  "iptables": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 1024,
      "Soft": 1024
    }
  }
}
EOF

# Restart Docker
systemctl restart docker

# Configure UFW firewall
echo "🔥 Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 3000
ufw allow 3001
ufw allow 3002
ufw allow 8080

# Configure fail2ban
echo "🚫 Configuring fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Configure AppArmor
echo "🛡️ Configuring AppArmor..."
systemctl enable apparmor
systemctl start apparmor

# Update ClamAV database
echo "🦠 Updating virus definitions..."
freshclam

# Configure auditd
echo "📊 Configuring audit logging..."
systemctl enable auditd
systemctl start auditd

# Configure Prometheus Node Exporter
echo "📈 Configuring monitoring..."
systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter

echo "✅ Security hardening completed!"