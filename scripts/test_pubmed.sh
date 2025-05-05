
#!/bin/bash

# URL encoding function
urlencode(){
  local s="$1" out="" pos c o
  for ((pos=0; pos<${#s}; pos++)); do
    c=${s:$pos:1}
    case "$c" in
      [a-zA-Z0-9.~_-]) o="$c" ;;
      *) printf -v o '%%%02X' "'$c" ;;
    esac
    out+="$o"
  done
  echo "$out"
}

# Test PubMed API - A simple script to test if the PubMed API is working correctly

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Function to log messages
log_message() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Test search
test_search() {
  local topic="artificial intelligence"
  local journal="nature"
  local days_back=30
  local max_results=1
  
  log_message "Testing PubMed search for '$topic' in '$journal' from the last $days_back days"
  
  # Date range
  local start_date=$(date -d "$days_back days ago" "+%Y/%m/%d")
  local end_date=$(date "+%Y/%m/%d")
  log_message "Date range: $start_date to $end_date"

  # Construct PubMed query with field and date range
  local term="${topic}[Title/Abstract] AND ${journal}[Journal] AND ${start_date}:${end_date}[pdat]"
  local encoded_query=$(urlencode "$term")
  
  log_message "Query: $query"
  log_message "Encoded query: $encoded_query"
  
  # Search PubMed using E-utilities
  local search_url="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=${encoded_query}&retmax=${max_results}&retmode=json"
  
  log_message "Search URL: $search_url"
  
  # Use curl to fetch results
  log_message "Fetching results..."
  local search_result=$(curl -s "$search_url")
  
  log_message "Search result: $search_result"
  
  # Extract PMIDs from search result
  local pmids=$(echo "$search_result" | grep -o '"idlist":\[[^]]*\]' | grep -o '[0-9]\+' | head -n "$max_results")
  
  if [ -z "$pmids" ]; then
    log_message "No papers found"
  else
    log_message "Papers found: $pmids"
    
    # Test fetching paper details
    for pmid in $pmids; do
      test_fetch "$pmid"
    done
  fi
}

# Test fetch
test_fetch() {
  local pmid=$1
  
  log_message "Testing PubMed fetch for PMID: $pmid"
  
  # Fetch paper details using E-utilities
  local fetch_url="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=${pmid}&retmode=xml"
  
  log_message "Fetch URL: $fetch_url"
  
  # Use curl to fetch results
  log_message "Fetching results..."
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
  
  log_message "Paper details:"
  log_message "Title: $title"
  log_message "Journal: $journal"
  log_message "Date: $year-$month-$day"
  log_message "Authors: $authors"
  log_message "DOI: $doi"
  log_message "Abstract: ${abstract:0:100}..."
  
  # Test Unpaywall API
  if [ ! -z "$doi" ]; then
    test_unpaywall "$doi"
  fi
}

# Test Unpaywall API
test_unpaywall() {
  local doi=$1
  
  log_message "Testing Unpaywall API for DOI: $doi"
  
  # Use Unpaywall API to find open access PDF
  local unpaywall_url="https://api.unpaywall.org/v2/$doi?email=paper_catchup@example.com"
  
  log_message "Unpaywall URL: $unpaywall_url"
  
  # Use curl to fetch results
  log_message "Fetching results..."
  local unpaywall_result=$(curl -s "$unpaywall_url")
  
  log_message "Unpaywall result: ${unpaywall_result:0:100}..."
  
  # Extract PDF URL from Unpaywall result
  local pdf_url=$(echo "$unpaywall_result" | grep -o '"best_oa_location":.*"url_for_pdf":.*"' | grep -o '"url_for_pdf":"[^"]*"' | sed 's/"url_for_pdf":"\(.*\)"/\1/')
  
  if [ -z "$pdf_url" ]; then
    log_message "No PDF URL found"
  else
    log_message "PDF URL found: $pdf_url"
  fi
}

# Main function
main() {
  log_message "Starting PubMed API test"
  
  # Test search
  test_search
  
  log_message "PubMed API test completed"
}

# Run main function
main
