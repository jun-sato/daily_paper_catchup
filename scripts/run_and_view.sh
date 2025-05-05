#!/bin/bash

# Run and View - Runs the paper_catchup.sh script and then displays the results

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAPER_CATCHUP_SCRIPT="$SCRIPT_DIR/paper_catchup.sh"
VIEW_PAPERS_SCRIPT="$SCRIPT_DIR/view_papers.sh"

# Function to log messages
log_message() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Check if scripts exist and are executable
if [ ! -f "$PAPER_CATCHUP_SCRIPT" ]; then
  log_message "Error: paper_catchup.sh not found at $PAPER_CATCHUP_SCRIPT"
  exit 1
fi

if [ ! -x "$PAPER_CATCHUP_SCRIPT" ]; then
  log_message "Making paper_catchup.sh executable"
  chmod +x "$PAPER_CATCHUP_SCRIPT"
fi

if [ ! -f "$VIEW_PAPERS_SCRIPT" ]; then
  log_message "Error: view_papers.sh not found at $VIEW_PAPERS_SCRIPT"
  exit 1
fi

if [ ! -x "$VIEW_PAPERS_SCRIPT" ]; then
  log_message "Making view_papers.sh executable"
  chmod +x "$VIEW_PAPERS_SCRIPT"
fi

# Run paper_catchup.sh
log_message "Running paper_catchup.sh"
"$PAPER_CATCHUP_SCRIPT"
CATCHUP_RESULT=$?

if [ $CATCHUP_RESULT -ne 0 ]; then
  log_message "Error: paper_catchup.sh failed with exit code $CATCHUP_RESULT"
  exit $CATCHUP_RESULT
fi

# Get today's date (compatible with both macOS and Linux)
TODAY=$(date "+%Y-%m-%d")

# Run view_papers.sh with today's date
log_message "Viewing papers from today ($TODAY)"
"$VIEW_PAPERS_SCRIPT" 0

log_message "Run and View completed"
