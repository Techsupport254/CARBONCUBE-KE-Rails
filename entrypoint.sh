#!/bin/bash
set -e

# Start cron service (if whenever gem is available)
if command -v whenever &> /dev/null; then
    echo "Updating crontab with Whenever schedule..."
    whenever --update-crontab
    cron
else
    echo "Whenever gem not found, skipping cron setup..."
fi

# Start the Rails server
exec "$@"
