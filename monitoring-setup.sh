#!/bin/bash

# Security Monitoring Setup Script
# This script sets up real-time security monitoring

set -e

LOG_FILE="/var/log/security-monitor.log"
ALERT_FILE="/var/log/security-alerts.log"

echo "📊 Setting up security monitoring..."

# Create security monitor script
cat > /usr/local/bin/security-monitor.sh << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/security-monitor.log"
ALERT_FILE="/var/log/security-alerts.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

alert() {
    echo "[$TIMESTAMP] ALERT: $1" | tee -a $LOG_FILE $ALERT_FILE
}

# Check for suspicious processes
SUSPICIOUS_PROCESSES=$(ps aux | grep -E "(wget|curl|bash|sh|nc|netcat|nmap|runnv|alive|lived)" | grep -v grep | wc -l)
if [ "$SUSPICIOUS_PROCESSES" -gt 0 ]; then
    alert "Suspicious processes detected: $SUSPICIOUS_PROCESSES"
fi

# Check for unusual network connections
UNUSUAL_CONNECTIONS=$(netstat -tuln | grep -E ":(22|80|443)" | wc -l)
if [ "$UNUSUAL_CONNECTIONS" -gt 10 ]; then
    alert "High number of network connections detected: $UNUSUAL_CONNECTIONS"
fi

# Check disk usage
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    alert "High disk usage detected: ${DISK_USAGE}%"
fi

# Check memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [ "$MEMORY_USAGE" -gt 90 ]; then
    alert "High memory usage detected: ${MEMORY_USAGE}%"
fi

echo "[$TIMESTAMP] Security check completed" >> $LOG_FILE
EOF

chmod +x /usr/local/bin/security-monitor.sh

# Configure logrotate for security logs
cat > /etc/logrotate.d/security-monitor << 'EOF'
/var/log/security-monitor.log /var/log/security-alerts.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload rsyslog 2>/dev/null || true
    endscript
}
EOF

# Add to cron for every 5 minutes
echo "*/5 * * * * root /usr/local/bin/security-monitor.sh" > /etc/cron.d/security-monitor

# Enable and start cron
systemctl enable cron
systemctl start cron

echo "✅ Security monitoring setup completed!"