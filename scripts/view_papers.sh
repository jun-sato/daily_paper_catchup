#!/bin/bash

# View Papers - Lists and allows viewing of collected papers and summaries

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DOWNLOADS_DIR="$PROJECT_DIR/downloads"

# Function to log messages
log_message() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to open a file with the default application
open_file() {
  local file="$1"
  
  if [ ! -f "$file" ]; then
    log_message "Error: File not found: $file"
    return 1
  fi
  
  log_message "Opening file: $file"
  
  if command_exists open; then
    # macOS
    open "$file"
  elif command_exists xdg-open; then
    # Linux
    xdg-open "$file"
  else
    log_message "Could not open file automatically"
    log_message "Please open the file manually at: $file"
  fi
}

# Function to list papers
list_papers() {
  local days_back="$1"
  local date_filter
  
  if [ -z "$days_back" ]; then
    date_filter=""
  else
    # Get date from N days ago (compatible with both macOS and Linux)
    if command_exists gdate; then
      # GNU date (macOS with coreutils)
      date_filter=$(gdate -d "$days_back days ago" "+%Y-%m-%d")
    elif date --version >/dev/null 2>&1; then
      # GNU date (Linux)
      date_filter=$(date -d "$days_back days ago" "+%Y-%m-%d")
    else
      # BSD date (macOS)
      date_filter=$(date -v-${days_back}d "+%Y-%m-%d")
    fi
  fi
  
  log_message "Listing papers"
  
  # Check if downloads directory exists
  if [ ! -d "$DOWNLOADS_DIR" ]; then
    log_message "No papers found. Downloads directory does not exist."
    return 1
  fi
  
  # Find all metadata.json files
  local metadata_files
  if [ -z "$date_filter" ]; then
    metadata_files=$(find "$DOWNLOADS_DIR" -name "metadata.json" | sort -r)
  else
    metadata_files=$(find "$DOWNLOADS_DIR" -path "*$date_filter*" -name "metadata.json" | sort -r)
  fi
  
  if [ -z "$metadata_files" ]; then
    log_message "No papers found."
    return 1
  fi
  
  # Display papers
  local count=0
  local papers=()
  local summaries=()
  local pdfs=()
  
  echo "Recent papers:"
  echo "-------------"
  
  while IFS= read -r metadata_file; do
    local dir=$(dirname "$metadata_file")
    local summary_file="$dir/summary.md"
    local pdf_file="$dir/paper.pdf"
    
    # Extract paper details from metadata
    local title=$(grep -o '"title": *"[^"]*"' "$metadata_file" | sed 's/"title": *"\(.*\)"/\1/')
    local journal=$(grep -o '"journal": *"[^"]*"' "$metadata_file" | sed 's/"journal": *"\(.*\)"/\1/')
    local topic=$(grep -o '"topic": *"[^"]*"' "$metadata_file" | sed 's/"topic": *"\(.*\)"/\1/')
    local has_pdf=$(grep -o '"has_pdf": *[^,}]*' "$metadata_file" | sed 's/"has_pdf": *\(.*\)/\1/')
    
    count=$((count+1))
    papers+=("$title")
    summaries+=("$summary_file")
    
    if [ "$has_pdf" = "1" ] || [ "$has_pdf" = "true" ]; then
      pdfs+=("$pdf_file")
      echo "$count. [$topic] $title ($journal) [PDF available]"
    else
      pdfs+=("")
      echo "$count. [$topic] $title ($journal)"
    fi
  done <<< "$metadata_files"
  
  if [ $count -eq 0 ]; then
    log_message "No papers found."
    return 1
  fi
  
  # Prompt user to view a paper
  local selection
  echo ""
  echo "Enter the number of the paper to view its summary, or 'q' to quit:"
  read -p "> " selection
  
  if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le $count ]; then
    local index=$((selection-1))
    
    # Open summary
    open_file "${summaries[$index]}"
    
    # Ask if user wants to open PDF if available
    if [ -n "${pdfs[$index]}" ] && [ -f "${pdfs[$index]}" ]; then
      echo ""
      read -p "Do you want to open the PDF? (y/n): " open_pdf
      if [[ "$open_pdf" =~ ^[Yy] ]]; then
        open_file "${pdfs[$index]}"
      fi
    fi
  elif [[ "$selection" != "q" ]]; then
    log_message "Invalid selection: $selection"
  fi
}

# Main function
main() {
  local days_back="$1"
  
  if [ "$days_back" = "-h" ] || [ "$days_back" = "--help" ]; then
    echo "Usage: $0 [days]"
    echo ""
    echo "Lists and allows viewing of collected papers and summaries."
    echo ""
    echo "Arguments:"
    echo "  days    Optional. Number of days back to filter papers."
    echo "          If not provided, all papers will be listed."
    echo ""
    echo "Examples:"
    echo "  $0        List all papers"
    echo "  $0 7      List papers from the last 7 days"
    exit 0
  fi
  
  list_papers "$days_back"
}

# Run main function with arguments
main "$@"
