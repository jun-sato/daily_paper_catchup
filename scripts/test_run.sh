#!/bin/bash

# Test Run - Runs a quick test of the paper_catchup.sh script with a smaller configuration

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/data/config.json"
TEMP_CONFIG_FILE="$PROJECT_DIR/data/config_test.json"
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

# Create a temporary test configuration
log_message "Creating temporary test configuration"
cat > "$TEMP_CONFIG_FILE" << EOF
{
  "journals": [
    "nature"
  ],
  "topics": [
    "artificial intelligence"
  ],
  "search_settings": {
    "days_back": 30,
    "max_papers_per_topic": 1,
    "min_relevance_score": 0.7
  },
  "schedule": {
    "time": "03:00"
  },
  "output_format": {
    "summary_sections": [
      "What was done",
      "Key findings",
      "Novelty",
      "Potential applications",
      "Limitations"
    ],
    "summary_length": "medium"
  }
}
EOF

# Backup original config
if [ -f "$CONFIG_FILE" ]; then
  log_message "Backing up original configuration"
  cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
fi

# Use test config
log_message "Using test configuration"
cp "$TEMP_CONFIG_FILE" "$CONFIG_FILE"

# Run paper_catchup.sh
log_message "Running paper_catchup.sh with test configuration"
"$PAPER_CATCHUP_SCRIPT"
TEST_RESULT=$?

# Restore original config
if [ -f "${CONFIG_FILE}.bak" ]; then
  log_message "Restoring original configuration"
  mv "${CONFIG_FILE}.bak" "$CONFIG_FILE"
fi

# Clean up
log_message "Cleaning up"
rm -f "$TEMP_CONFIG_FILE"

if [ $TEST_RESULT -eq 0 ]; then
  log_message "Test completed successfully"
  log_message "Check the downloads directory for results"
else
  log_message "Test failed with exit code $TEST_RESULT"
  log_message "Check the log file at data/paper_catchup.log for details"
fi

exit $TEST_RESULT
