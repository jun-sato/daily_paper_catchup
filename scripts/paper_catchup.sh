#!/bin/bash

# Test PubMed API - A simple script to test PubMed E-utilities search and fetch

command_exists() { command -v "$1" >/dev/null 2>&1; }

# URL encoding function
urlencode() {
  local s="$1" out="" pos c o
  for (( pos=0; pos<${#s}; pos++ )); do
    c=${s:$pos:1}
    case "$c" in
      [a-zA-Z0-9.~_-]) o="$c" ;;
      *) printf -v o '%%%02X' "'$c" ;;
    esac
    out+="$o"
  done
  echo "$out"
}

# Simple logger
log_message() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

test_search() {
  local topic="artificial intelligence"
  local journal="Nature"
  local days_back=30
  local max_results=1

  # Compute start_date: use GNU date if available, otherwise BSD date
  if command_exists gdate; then
    start_date=$(gdate -d "$days_back days ago" "+%Y/%m/%d")
  else
    start_date=$(date -v-"$days_back"d "+%Y/%m/%d")
  fi
  end_date=$(date "+%Y/%m/%d")
  log_message "Date range: $start_date to $end_date"

  # Construct PubMed query
  local term="${topic}[Title/Abstract] AND ${journal}[Journal] AND ${start_date}:${end_date}[pdat]"
  local encoded_term
  encoded_term=$(urlencode "$term")
  log_message "Query: $term"

  local search_url="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
  search_url+="?db=pubmed&retmode=json&retmax=${max_results}&term=${encoded_term}"
  log_message "Search URL: $search_url"

  # Execute search
  local search_result
  search_result=$(curl -s "$search_url")
  log_message "Search result: $search_result"

  # Extract PMIDs
  local pmids
  pmids=$(echo "$search_result" | jq -r '.esearchresult.idlist[]' | head -n "$max_results")
  if [ -z "$pmids" ]; then
    log_message "No papers found"
  else
    log_message "Papers found: $pmids"
  fi
}

main() {
  log_message "Starting PubMed API test"
  test_search
  log_message "PubMed API test completed"
}

main