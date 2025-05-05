#!/bin/bash

# Setup Scheduler - Sets up a cron job to run paper_catchup.sh daily at 3 AM

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PAPER_CATCHUP_SCRIPT="$SCRIPT_DIR/paper_catchup.sh"

# Function to log messages
log_message() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Check if paper_catchup.sh exists and is executable
if [ ! -f "$PAPER_CATCHUP_SCRIPT" ]; then
  log_message "Error: paper_catchup.sh not found at $PAPER_CATCHUP_SCRIPT"
  exit 1
fi

if [ ! -x "$PAPER_CATCHUP_SCRIPT" ]; then
  log_message "Making paper_catchup.sh executable"
  chmod +x "$PAPER_CATCHUP_SCRIPT"
fi

# Create a temporary file for the crontab
TEMP_CRONTAB=$(mktemp)

# Export current crontab
crontab -l > "$TEMP_CRONTAB" 2>/dev/null || echo "" > "$TEMP_CRONTAB"

# Check if the cron job already exists
if grep -q "$PAPER_CATCHUP_SCRIPT" "$TEMP_CRONTAB"; then
  log_message "Cron job already exists. Updating..."
  # Remove existing cron job
  grep -v "$PAPER_CATCHUP_SCRIPT" "$TEMP_CRONTAB" > "${TEMP_CRONTAB}.new"
  mv "${TEMP_CRONTAB}.new" "$TEMP_CRONTAB"
fi

# Add the new cron job
echo "0 3 * * * $PAPER_CATCHUP_SCRIPT" >> "$TEMP_CRONTAB"

# Install the new crontab
crontab "$TEMP_CRONTAB"

# Clean up
rm "$TEMP_CRONTAB"

log_message "Scheduler setup complete. Paper Catchup will run daily at 3 AM."
log_message "You can verify the scheduled job with 'crontab -l'"
