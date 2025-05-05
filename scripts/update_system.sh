#!/bin/bash

# Update System - Updates the Paper Catchup system to the latest version

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/data/config.json"
BACKUP_DIR="$PROJECT_DIR/data/backups"

# Function to log messages
log_message() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to backup configuration
backup_config() {
  log_message "Backing up configuration"
  
  # Create backup directory if it doesn't exist
  mkdir -p "$BACKUP_DIR"
  
  # Create backup with timestamp
  local timestamp=$(date "+%Y%m%d%H%M%S")
  local backup_file="$BACKUP_DIR/config_${timestamp}.json"
  
  if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$backup_file"
    log_message "Configuration backed up to: $backup_file"
  else
    log_message "No configuration file found to backup"
  fi
}

# Function to update configuration format
update_config_format() {
  log_message "Checking configuration format"
  
  if [ ! -f "$CONFIG_FILE" ]; then
    log_message "No configuration file found"
    return 1
  fi
  
  # Check if search_settings exists
  if ! grep -q '"search_settings"' "$CONFIG_FILE"; then
    log_message "Updating configuration format: Adding search_settings"
    
    # Create a temporary file
    local temp_file=$(mktemp)
    
    # Extract existing settings
    local days_back=$(grep -o '"days_back": *[0-9]*' "$CONFIG_FILE" | sed 's/"days_back": *\([0-9]*\)/\1/')
    local max_papers=$(grep -o '"max_papers_per_topic": *[0-9]*' "$CONFIG_FILE" | sed 's/"max_papers_per_topic": *\([0-9]*\)/\1/')
    
    # Set defaults if not found
    days_back=${days_back:-7}
    max_papers=${max_papers:-3}
    
    # Remove old settings if they exist at the top level
    grep -v '"days_back":' "$CONFIG_FILE" | grep -v '"max_papers_per_topic":' > "$temp_file"
    
    # Add search_settings object
    sed -i.bak 's/\(  "topics": \[[^]]*\]\),/\1,\n  "search_settings": {\n    "days_back": '"$days_back"',\n    "max_papers_per_topic": '"$max_papers"',\n    "min_relevance_score": 0.7\n  },/g' "$temp_file"
    
    # Replace the original file
    mv "$temp_file" "$CONFIG_FILE"
    
    log_message "Configuration format updated"
  fi
  
  # Check if schedule exists
  if ! grep -q '"schedule"' "$CONFIG_FILE"; then
    log_message "Updating configuration format: Adding schedule"
    
    # Create a temporary file
    local temp_file=$(mktemp)
    
    # Copy the original file
    cp "$CONFIG_FILE" "$temp_file"
    
    # Add schedule object
    sed -i.bak 's/\(  "search_settings": {[^}]*}\),/\1,\n  "schedule": {\n    "time": "03:00"\n  },/g' "$temp_file"
    
    # Replace the original file
    mv "$temp_file" "$CONFIG_FILE"
    
    log_message "Configuration format updated"
  fi
  
  # Check if output_format exists
  if ! grep -q '"output_format"' "$CONFIG_FILE"; then
    log_message "Updating configuration format: Adding output_format"
    
    # Create a temporary file
    local temp_file=$(mktemp)
    
    # Copy the original file
    cp "$CONFIG_FILE" "$temp_file"
    
    # Add output_format object
    sed -i.bak 's/\(  "schedule": {[^}]*}\),/\1,\n  "output_format": {\n    "summary_sections": [\n      "What was done",\n      "Key findings",\n      "Novelty",\n      "Potential applications",\n      "Limitations"\n    ],\n    "summary_length": "medium"\n  },/g' "$temp_file"
    
    # Replace the original file
    mv "$temp_file" "$CONFIG_FILE"
    
    log_message "Configuration format updated"
  fi
  
  # Clean up backup files
  rm -f "$CONFIG_FILE.bak"
  
  log_message "Configuration format check complete"
}

# Function to update scripts
update_scripts() {
  log_message "Making scripts executable"
  
  chmod +x "$SCRIPT_DIR/paper_catchup.sh"
  chmod +x "$SCRIPT_DIR/setup_scheduler.sh"
  chmod +x "$SCRIPT_DIR/test_run.sh"
  chmod +x "$SCRIPT_DIR/view_papers.sh"
  chmod +x "$PROJECT_DIR/install.sh"
  
  log_message "Scripts are now executable"
}

# Main function
main() {
  log_message "Starting Paper Catchup system update"
  
  # Backup configuration
  backup_config
  
  # Update configuration format
  update_config_format
  
  # Update scripts
  update_scripts
  
  # Update scheduler if requested
  if prompt_yes_no "Do you want to update the scheduler?"; then
    log_message "Updating scheduler"
    "$SCRIPT_DIR/setup_scheduler.sh"
  fi
  
  log_message "Paper Catchup system update complete"
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

# Run main function
main
