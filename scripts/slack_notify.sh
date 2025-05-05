#!/bin/bash

# Slack Notify - Sends notifications to Slack about collected papers

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/data/slack_config.json"

# Function to log messages
log_message() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to parse JSON (basic implementation)
parse_json() {
  local json_file=$1
  local key=$2
  grep -o "\"$key\":[^,}]*" "$json_file" | sed 's/.*: *"\?\([^",}]*\)"\?.*/\1/'
}

# Function to send a message to Slack
send_slack_message() {
  local webhook_url="$1"
  local message="$2"
  
  if [ -z "$webhook_url" ]; then
    log_message "Error: No webhook URL provided"
    return 1
  fi
  
  if [ -z "$message" ]; then
    log_message "Error: No message provided"
    return 1
  fi
  
  log_message "Sending message to Slack"
  
  # Use curl to send message to Slack
  local response=$(curl -s -X POST -H 'Content-type: application/json' --data "$message" "$webhook_url")
  
  if [ "$response" = "ok" ]; then
    log_message "Message sent successfully"
    return 0
  else
    log_message "Error sending message: $response"
    return 1
  fi
}

# Function to create a Slack message for a paper
create_paper_message() {
  local metadata_file="$1"
  local summary_file="$2"
  
  # Extract paper details from metadata
  local title=$(grep -o '"title": *"[^"]*"' "$metadata_file" | sed 's/"title": *"\(.*\)"/\1/')
  local journal=$(grep -o '"journal": *"[^"]*"' "$metadata_file" | sed 's/"journal": *"\(.*\)"/\1/')
  local topic=$(grep -o '"topic": *"[^"]*"' "$metadata_file" | sed 's/"topic": *"\(.*\)"/\1/')
  local doi=$(grep -o '"doi": *"[^"]*"' "$metadata_file" | sed 's/"doi": *"\(.*\)"/\1/')
  local has_pdf=$(grep -o '"has_pdf": *[^,}]*' "$metadata_file" | sed 's/"has_pdf": *\(.*\)/\1/')
  
  # Extract summary sections from summary file
  local what_was_done=$(grep -A 1 "### What was done" "$summary_file" | tail -1)
  local key_findings=$(grep -A 3 "### Key findings" "$summary_file" | tail -3 | sed 's/^/• /' | tr '\n' ' ')
  local novelty=$(grep -A 2 "### Novelty" "$summary_file" | tail -2 | sed 's/^/• /' | tr '\n' ' ')
  
  # Create DOI link
  local doi_link=""
  if [ ! -z "$doi" ]; then
    doi_link="https://doi.org/$doi"
  fi
  
  # Create message
  local message="{
    \"blocks\": [
      {
        \"type\": \"header\",
        \"text\": {
          \"type\": \"plain_text\",
          \"text\": \"New Paper: $title\",
          \"emoji\": true
        }
      },
      {
        \"type\": \"section\",
        \"fields\": [
          {
            \"type\": \"mrkdwn\",
            \"text\": \"*Journal:*\\n$journal\"
          },
          {
            \"type\": \"mrkdwn\",
            \"text\": \"*Topic:*\\n$topic\"
          }
        ]
      },
      {
        \"type\": \"section\",
        \"text\": {
          \"type\": \"mrkdwn\",
          \"text\": \"*What was done:*\\n$what_was_done\"
        }
      },
      {
        \"type\": \"section\",
        \"text\": {
          \"type\": \"mrkdwn\",
          \"text\": \"*Key findings:*\\n$key_findings\"
        }
      }"
  
  # Add novelty section if available
  if [ ! -z "$novelty" ]; then
    message="$message,
      {
        \"type\": \"section\",
        \"text\": {
          \"type\": \"mrkdwn\",
          \"text\": \"*Novelty:*\\n$novelty\"
        }
      }"
  fi
  
  # Add DOI link if available
  if [ ! -z "$doi_link" ]; then
    message="$message,
      {
        \"type\": \"section\",
        \"text\": {
          \"type\": \"mrkdwn\",
          \"text\": \"<$doi_link|View paper on publisher's website>\"
        }
      }"
  fi
  
  # Add PDF availability
  if [ "$has_pdf" = "1" ] || [ "$has_pdf" = "true" ]; then
    message="$message,
      {
        \"type\": \"context\",
        \"elements\": [
          {
            \"type\": \"mrkdwn\",
            \"text\": \":white_check_mark: PDF downloaded\"
          }
        ]
      }"
  else
    message="$message,
      {
        \"type\": \"context\",
        \"elements\": [
          {
            \"type\": \"mrkdwn\",
            \"text\": \":x: PDF not available\"
          }
        ]
      }"
  fi
  
  # Close the message
  message="$message
    ]
  }"
  
  echo "$message"
}

# Function to notify about a single paper
notify_paper() {
  local metadata_file="$1"
  local webhook_url="$2"
  
  if [ ! -f "$metadata_file" ]; then
    log_message "Error: Metadata file not found: $metadata_file"
    return 1
  fi
  
  local dir=$(dirname "$metadata_file")
  local summary_file="$dir/summary.md"
  
  if [ ! -f "$summary_file" ]; then
    log_message "Error: Summary file not found: $summary_file"
    return 1
  fi
  
  # Create message
  local message=$(create_paper_message "$metadata_file" "$summary_file")
  
  # Send message
  send_slack_message "$webhook_url" "$message"
}

# Function to notify about all papers in a directory
notify_papers() {
  local directory="$1"
  local webhook_url="$2"
  local max_papers="$3"
  
  if [ ! -d "$directory" ]; then
    log_message "Error: Directory not found: $directory"
    return 1
  fi
  
  # Find all metadata.json files
  local metadata_files=$(find "$directory" -name "metadata.json" | sort -r | head -n "$max_papers")
  
  if [ -z "$metadata_files" ]; then
    log_message "No papers found in directory: $directory"
    return 1
  fi
  
  # Notify about each paper
  local count=0
  while IFS= read -r metadata_file; do
    notify_paper "$metadata_file" "$webhook_url"
    count=$((count+1))
    
    # Add a small delay between notifications to avoid rate limiting
    sleep 1
  done <<< "$metadata_files"
  
  log_message "Notified about $count papers"
}

# Main function
main() {
  local directory="$1"
  local max_papers="$2"
  
  # Set default max papers
  max_papers=${max_papers:-5}
  
  # Check if config file exists
  if [ ! -f "$CONFIG_FILE" ]; then
    log_message "Error: Config file not found at $CONFIG_FILE"
    log_message "Please create a config file with your Slack webhook URL:"
    log_message "{\"webhook_url\": \"https://hooks.slack.com/services/YOUR/WEBHOOK/URL\"}"
    exit 1
  fi
  
  # Read webhook URL from config
  local webhook_url=$(parse_json "$CONFIG_FILE" "webhook_url")
  
  if [ -z "$webhook_url" ]; then
    log_message "Error: No webhook URL found in config file"
    exit 1
  fi
  
  # If directory is provided, notify about papers in that directory
  if [ ! -z "$directory" ]; then
    notify_papers "$directory" "$webhook_url" "$max_papers"
  else
    # Otherwise, notify about papers in the downloads directory
    notify_papers "$PROJECT_DIR/downloads" "$webhook_url" "$max_papers"
  fi
}

# If script is run directly, run main function with arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
