#!/bin/bash

# Paper Catchup - Automatic scientific paper collector and summarizer
# This script searches for papers based on configured topics and journals,
# downloads available PDFs, and creates summary files.

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/data/config.json"
DOWNLOADS_DIR="$PROJECT_DIR/downloads"
DATA_DIR="$PROJECT_DIR/data"
LOG_FILE="$DATA_DIR/paper_catchup.log"

# Function to log messages
log_message() {
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function to parse JSON (basic implementation)
parse_json() {
  local json_file=$1
  local key=$2
  grep -o "\"$key\":[^,}]*" "$json_file" | sed 's/.*: *"\?\([^",}]*\)"\?.*/\1/'
}

# Function to parse JSON array (basic implementation)
parse_json_array() {
  local json_file=$1
  local key=$2
  
  # Use a more direct approach to extract array items
  grep -o "\"$key\"[[:space:]]*:[[:space:]]*\\[[^]]*\\]" "$json_file" | 
    sed 's/.*\[\(.*\)\].*/\1/' | 
    grep -o '"[^"]*"' | 
    sed 's/"//g'
}

# Function to search for papers using PubMed E-utilities API
search_papers() {
  local topic=$1
  local journal=$2
  local days_back=$3
  local max_results=$4
  
  # Format date for PubMed query (compatible with both macOS and Linux)
  if command -v gdate >/dev/null 2>&1; then
    # GNU date (macOS with coreutils)
    local date_range=$(gdate -d "$days_back days ago" "+%Y/%m/%d")
  elif date --version >/dev/null 2>&1; then
    # GNU date (Linux)
    local date_range=$(date -d "$days_back days ago" "+%Y/%m/%d")
  else
    # BSD date (macOS)
    local date_range=$(date -v-${days_back}d "+%Y/%m/%d")
  fi
  
  log_message "Searching for papers on '$topic' in '$journal' from the last $days_back days"
  
  # Construct PubMed query
  local query="$topic AND $journal[journal] AND $date_range:3000[pdat]"
  local encoded_query=$(echo "$query" | sed 's/ /+/g')
  
  # Search PubMed using E-utilities
  local search_url="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=${encoded_query}&retmax=${max_results}&retmode=json"
  
  # Use curl to fetch results
  local search_result=$(curl -s "$search_url")
  
  # Extract PMIDs from search result
  local pmids=$(echo "$search_result" | grep -o '"idlist":\[[^]]*\]' | grep -o '[0-9]\+' | head -n "$max_results")
  
  if [ -z "$pmids" ]; then
    log_message "No papers found for '$topic' in '$journal'"
    return
  fi
  
  # Process each paper
  for pmid in $pmids; do
    process_paper "$pmid" "$topic" "$journal"
  done
}

# Function to get paper details using PubMed E-utilities API
get_paper_details() {
  local pmid=$1
  
  log_message "Getting details for paper PMID: $pmid"
  
  # Fetch paper details using E-utilities
  local fetch_url="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=${pmid}&retmode=xml"
  local paper_details=$(curl -s "$fetch_url")
  
  # Create a temporary file to store the XML
  local temp_file=$(mktemp)
  echo "$paper_details" > "$temp_file"
  
  # Extract paper details using grep and sed
  local title=$(grep -o "<ArticleTitle>.*</ArticleTitle>" "$temp_file" | sed 's/<ArticleTitle>\(.*\)<\/ArticleTitle>/\1/')
  local journal=$(grep -o "<Title>.*</Title>" "$temp_file" | head -1 | sed 's/<Title>\(.*\)<\/Title>/\1/')
  local year=$(grep -o "<Year>.*</Year>" "$temp_file" | head -1 | sed 's/<Year>\(.*\)<\/Year>/\1/')
  local month=$(grep -o "<Month>.*</Month>" "$temp_file" | head -1 | sed 's/<Month>\(.*\)<\/Month>/\1/')
  local day=$(grep -o "<Day>.*</Day>" "$temp_file" | head -1 | sed 's/<Day>\(.*\)<\/Day>/\1/')
  local authors=$(grep -o "<LastName>.*</LastName>" "$temp_file" | sed 's/<LastName>\(.*\)<\/LastName>/\1/' | tr '\n' ',' | sed 's/,$//')
  
  # Extract abstract
  local abstract=$(grep -o "<AbstractText>.*</AbstractText>" "$temp_file" | sed 's/<AbstractText>\(.*\)<\/AbstractText>/\1/' | tr '\n' ' ')
  
  # Extract DOI
  local doi=$(grep -o "<ArticleId IdType=\"doi\">.*</ArticleId>" "$temp_file" | sed 's/<ArticleId IdType="doi">\(.*\)<\/ArticleId>/\1/')
  
  # Clean up
  rm "$temp_file"
  
  # Return paper details as a pipe-separated string
  echo "$title|$journal|$year-$month-$day|$authors|$abstract|$doi"
}

# Function to try to find PDF using Unpaywall API
find_pdf_url() {
  local doi=$1
  
  if [ -z "$doi" ]; then
    return
  fi
  
  log_message "Looking for PDF for DOI: $doi"
  
  # Use Unpaywall API to find open access PDF
  local unpaywall_url="https://api.unpaywall.org/v2/$doi?email=paper_catchup@example.com"
  local unpaywall_result=$(curl -s "$unpaywall_url")
  
  # Extract PDF URL from Unpaywall result
  local pdf_url=$(echo "$unpaywall_result" | grep -o '"best_oa_location":.*"url_for_pdf":.*"' | grep -o '"url_for_pdf":"[^"]*"' | sed 's/"url_for_pdf":"\(.*\)"/\1/')
  
  echo "$pdf_url"
}

# Function to download PDF
download_pdf() {
  local pdf_url=$1
  local output_file=$2
  
  if [ -z "$pdf_url" ]; then
    log_message "No PDF URL available"
    return 1
  fi
  
  log_message "Downloading PDF from: $pdf_url"
  
  # Use curl to download PDF
  curl -s -L -o "$output_file" "$pdf_url"
  
  if [ $? -eq 0 ] && [ -s "$output_file" ]; then
    log_message "PDF downloaded successfully to: $output_file"
    return 0
  else
    log_message "Failed to download PDF"
    rm -f "$output_file"
    return 1
  fi
}

# Function to create a summary file
create_summary() {
  local paper_details=$1
  local topic=$2
  local output_file=$3
  local has_pdf=$4
  
  # Parse paper details
  IFS='|' read -r title journal date authors abstract doi <<< "$paper_details"
  
  log_message "Creating summary for: $title"
  
  # Create summary file
  cat > "$output_file" << EOF
# Paper Summary

## Basic Information
- **Title**: $title
- **Journal**: $journal
- **Date**: $date
- **Authors**: $authors
- **DOI**: $doi
- **Topic**: $topic
- **PDF Available**: $([ "$has_pdf" -eq 1 ] && echo "Yes" || echo "No")

## Abstract
$abstract

## Summary

### What was done
$(echo "$abstract" | sed -n '1p')

### Key findings
$(echo "$abstract" | grep -i "result\|find\|show\|demonstrate" | head -3)

### Novelty
$(echo "$abstract" | grep -i "novel\|new\|first\|unique\|innovative" | head -2)

### Potential applications
$(echo "$abstract" | grep -i "application\|implication\|potential\|future\|suggest" | head -2)

### Limitations
$(echo "$abstract" | grep -i "limitation\|challenge\|future work\|however" | head -2)

## Notes
- Summary generated automatically by Paper Catchup on $(date "+%Y-%m-%d %H:%M:%S")
- This is a basic summary based on the abstract. For a more comprehensive understanding, please read the full paper.
EOF

  log_message "Summary created successfully at: $output_file"
}

# Function to process a single paper
process_paper() {
  local pmid=$1
  local topic=$2
  local journal=$3
  
  log_message "Processing paper PMID: $pmid for topic: $topic"
  
  # Get paper details
  local paper_details=$(get_paper_details "$pmid")
  
  # Parse paper details
  IFS='|' read -r title journal_name date authors abstract doi <<< "$paper_details"
  
  # Create directory for this paper
  local paper_dir="$DOWNLOADS_DIR/$(date "+%Y-%m-%d")_${topic// /_}/${pmid}"
  mkdir -p "$paper_dir"
  
  # Try to find and download PDF
  local has_pdf=0
  if [ ! -z "$doi" ]; then
    local pdf_url=$(find_pdf_url "$doi")
    if [ ! -z "$pdf_url" ]; then
      local pdf_file="$paper_dir/paper.pdf"
      if download_pdf "$pdf_url" "$pdf_file"; then
        has_pdf=1
      fi
    fi
  fi
  
  # Create summary file
  local summary_file="$paper_dir/summary.md"
  create_summary "$paper_details" "$topic" "$summary_file" "$has_pdf"
  
  # Create metadata file
  local metadata_file="$paper_dir/metadata.json"
  cat > "$metadata_file" << EOF
{
  "pmid": "$pmid",
  "title": "$title",
  "journal": "$journal_name",
  "date": "$date",
  "authors": "$authors",
  "doi": "$doi",
  "topic": "$topic",
  "has_pdf": $has_pdf,
  "processed_date": "$(date "+%Y-%m-%d %H:%M:%S")"
}
EOF

  log_message "Paper processed successfully: $title"
}

# Function to send Slack notifications
send_slack_notifications() {
  local slack_config="$PROJECT_DIR/data/slack_config.json"
  local slack_script="$SCRIPT_DIR/slack_notify.sh"
  
  # Check if Slack config and script exist
  if [ -f "$slack_config" ] && [ -f "$slack_script" ]; then
    log_message "Sending Slack notifications"
    
    # Make sure the script is executable
    if [ ! -x "$slack_script" ]; then
      chmod +x "$slack_script"
    fi
    
    # Run the Slack notification script
    "$slack_script" "$DOWNLOADS_DIR/$(date "+%Y-%m-%d")"
  else
    log_message "Slack notifications not configured. Skipping."
  fi
}

# Main function
main() {
  log_message "Starting Paper Catchup"
  
  # Create necessary directories
  mkdir -p "$DOWNLOADS_DIR"
  mkdir -p "$DATA_DIR"
  
  # Check if config file exists
  if [ ! -f "$CONFIG_FILE" ]; then
    log_message "Error: Config file not found at $CONFIG_FILE"
    exit 1
  fi
  
  # Read configuration
  local days_back=$(grep -o '"days_back": *[0-9]*' "$CONFIG_FILE" | sed 's/"days_back": *\([0-9]*\)/\1/')
  local max_papers=$(grep -o '"max_papers_per_topic": *[0-9]*' "$CONFIG_FILE" | sed 's/"max_papers_per_topic": *\([0-9]*\)/\1/')
  
  # Set defaults if not found
  days_back=${days_back:-7}
  max_papers=${max_papers:-3}
  
  log_message "Using settings: days_back=$days_back, max_papers=$max_papers"
  
  # Get topics and journals from config
  local topics=$(parse_json_array "$CONFIG_FILE" "topics")
  local journals=$(parse_json_array "$CONFIG_FILE" "journals")
  
  # Process each topic and journal combination
  for topic in $topics; do
    for journal in $journals; do
      search_papers "$topic" "$journal" "$days_back" "$max_papers"
    done
  done
  
  # Send Slack notifications
  send_slack_notifications
  
  log_message "Paper Catchup completed successfully"
}

# Run main function
main
