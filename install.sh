#!/bin/bash

# Paper Catchup - Installation Script
# This script guides the user through the setup process for Paper Catchup

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/data/config.json"
SETUP_SCHEDULER_SCRIPT="$SCRIPT_DIR/scripts/setup_scheduler.sh"
TEST_RUN_SCRIPT="$SCRIPT_DIR/scripts/test_run.sh"

# Function to log messages
log_message() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to prompt for yes/no
prompt_yes_no() {
  local prompt="$1"
  local response
  
  while true; do
    read -p "$prompt (y/n): " response
    case "$response" in
      [Yy]* ) return 0;;
      [Nn]* ) return 1;;
      * ) echo "Please answer yes (y) or no (n).";;
    esac
  done
}

# Check for required dependencies
check_dependencies() {
  log_message "Checking dependencies"
  
  local missing_deps=0
  
  for cmd in curl grep sed; do
    if ! command_exists "$cmd"; then
      log_message "Error: Required command '$cmd' not found"
      missing_deps=1
    fi
  done
  
  if [ $missing_deps -eq 1 ]; then
    log_message "Please install the missing dependencies and try again"
    exit 1
  fi
  
  log_message "All dependencies are installed"
}

# Make scripts executable
make_scripts_executable() {
  log_message "Making scripts executable"
  
  chmod +x "$SCRIPT_DIR/scripts/paper_catchup.sh"
  chmod +x "$SCRIPT_DIR/scripts/setup_scheduler.sh"
  chmod +x "$SCRIPT_DIR/scripts/test_run.sh"
  
  log_message "Scripts are now executable"
}

# Main function
main() {
  log_message "Welcome to Paper Catchup Installation"
  
  # Check dependencies
  check_dependencies
  
  # Make scripts executable
  make_scripts_executable
  
  # Ask if user wants to customize configuration
  if prompt_yes_no "Do you want to customize the configuration?"; then
    # Open the configuration file in the default editor
    log_message "Opening configuration file in editor"
    log_message "Please edit the file to customize your topics, journals, and other settings"
    log_message "Save and close the editor when you're done"
    
    if command_exists open; then
      # macOS
      open -t "$CONFIG_FILE"
    elif command_exists xdg-open; then
      # Linux
      xdg-open "$CONFIG_FILE"
    else
      log_message "Could not open editor automatically"
      log_message "Please edit the configuration file manually at: $CONFIG_FILE"
    fi
    
    # Wait for user to confirm they've edited the file
    read -p "Press Enter when you've finished editing the configuration file..."
  fi
  
  # Ask if user wants to set up the scheduler
  if prompt_yes_no "Do you want to set up the scheduler to run Paper Catchup daily at 3 AM?"; then
    log_message "Setting up scheduler"
    "$SETUP_SCHEDULER_SCRIPT"
  else
    log_message "Scheduler not set up. You can run the script manually or set up the scheduler later"
  fi
  
  # Ask if user wants to run a test
  if prompt_yes_no "Do you want to run a test to make sure everything is working?"; then
    log_message "Running test"
    "$TEST_RUN_SCRIPT"
  else
    log_message "Test not run. You can run a test later with: $TEST_RUN_SCRIPT"
  fi
  
  log_message "Installation complete!"
  log_message "You can now use Paper Catchup to automatically collect and summarize scientific papers"
  log_message "For more information, see the README.md file"
}

# Run main function
main
