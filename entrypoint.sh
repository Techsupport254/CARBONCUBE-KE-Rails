#!/bin/bash
set -e

# Update crontab with the Whenever schedule
whenever --update-crontab

# Start cron service
cron

# Start the Rails server
exec "$@"
