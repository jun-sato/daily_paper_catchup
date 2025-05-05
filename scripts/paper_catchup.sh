#!/bin/bash
# Paper Catchup - Automatic scientific paper collector and summarizer
# This script searches for papers based on configured topics and journals,
# downloads available PDFs, and creates structured summaries.

# --- プロジェクトパスの設定 ---------------------------------
# このスクリプトが置かれているディレクトリ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# プロジェクトルート（scripts/ の一つ上）
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
# ダウンロード結果を格納するディレクトリ
DOWNLOADS_DIR="$PROJECT_DIR/downloads"
# ログ／設定ファイル置き場
DATA_DIR="$PROJECT_DIR/data"
CONFIG_FILE="$DATA_DIR/config.json"
LOG_FILE="$DATA_DIR/paper_catchup.log"

# 必要なら downloads ディレクトリを作成
mkdir -p "$DOWNLOADS_DIR"


# Ensure required commands
command_exists(){ command -v "$1" >/dev/null 2>&1; }
if ! command_exists jq; then
  echo "Error: 'jq' is required. Install it and retry." >&2
  exit 1
fi

# URL encoding helper
enurl(){
  local s="$1" out="" c
  for ((i=0; i<${#s}; i++)); do
    c=${s:i:1}
    case "$c" in
      [a-zA-Z0-9._~-]) out+="$c" ;; 
      *) printf -v out "%s%%%02X" "$out" "'${c}";;
    esac
  done
  echo "$out"
}

# Logging helper
log(){
  local ts
  ts=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$ts] $1"
}

# Search and process papers from PubMed
search_papers(){
  local topic="$1" journal="$2" days_back=$3 max_res=$4
  local start_date end_date term encoded url result pmids
  start_date=$(date -d "$days_back days ago" "+%Y/%m/%d")
  end_date=$(date "+%Y/%m/%d")
  log "Searching '$topic' in '$journal' from $start_date to $end_date"

  term="${topic}[Title/Abstract] AND ${journal}[Journal] AND ${start_date}:${end_date}[pdat]"
  encoded=$(enurl "$term")
  url="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmode=json&retmax=$max_res&term=$encoded"

  result=$(curl -s "$url")
  pmids=$(echo "$result" | jq -r '.esearchresult.idlist[]' | head -n "$max_res")
  if [[ -z "$pmids" ]]; then
    log "No papers found for '$topic' in '$journal'"
    return
  fi
  for pmid in $pmids; do
    process_paper "$pmid" "$topic" "$journal"
  done
}

# Fetch detailed paper info
process_paper(){
  local pmid=$1 topic="$2" journal="$3"
  local tmp title authors abstract doi dir summary
  log "Processing PMID: $pmid"
  tmp=$(mktemp)
  curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=$pmid&retmode=xml" > "$tmp"

  title=$(grep -o '<ArticleTitle>.*</ArticleTitle>' "$tmp" | sed 's/<[^>]*>//g')
  authors=$(grep -o '<LastName>.*</LastName>' "$tmp" | sed 's/<[^>]*>//g' | tr '\n' ', ' | sed 's/, $//')
  abstract=$(grep -o '<AbstractText>.*</AbstractText>' "$tmp" | sed 's/<[^>]*>//g' | tr -d '\n')
  doi=$(grep -o '<ArticleId IdType="doi">.*</ArticleId>' "$tmp" | sed 's/<[^>]*>//g')
  rm "$tmp"

  dir="$DOWNLOADS_DIR/$(date +%Y-%m-%d)_${topic// /_}/$pmid"
  mkdir -p "$dir"

  # PDF via Unpaywall
  if [[ -n "$doi" ]]; then
    local pdf_url unres
    unres=$(curl -s "https://api.unpaywall.org/v2/$doi?email=paper_catchup@example.com")
    pdf_url=$(echo "$unres" | jq -r '.best_oa_location.url_for_pdf // empty')
    if [[ -n "$pdf_url" ]]; then
      curl -sL "$pdf_url" -o "$dir/paper.pdf"
      [[ -s "$dir/paper.pdf" ]] && pdf_avail="Yes" || pdf_avail="No"
    else
      pdf_avail="No"
    fi
  else
    pdf_avail="No"
  fi

  # Write summary markdown
  summary="$dir/summary.md"
  cat > "$summary" <<EOF
# $title

**Journal:** $journal  
**Authors:** $authors  
**DOI:** $doi  
**PDF:** $pdf_avail

## Abstract
$abstract

## Summary
- **What was done:** $(echo "$abstract" | head -n1)  
- **Key findings:** $(echo "$abstract" | grep -Ei 'result|find|show|demonstrate' | head -n1)  
- **Novelty:** $(echo "$abstract" | grep -Ei 'novel|unique|innovative' | head -n1)  
- **Applications:** $(echo "$abstract" | grep -Ei 'application|implication' | head -n1)  
- **Limitations:** $(echo "$abstract" | grep -Ei 'limitation|challenge|however' | head -n1)
EOF

  log "Saved summary for PMID $pmid"
}

main(){
  log "Starting Paper Catchup"
  # Load config
  local cfg="data/config.json"
  days_back=$(jq -r '.search_settings.days_back' "$cfg")
  max=$(jq -r '.search_settings.max_papers_per_topic' "$cfg")
  mapfile -t topics < <(jq -r '.topics[]' "$cfg")
  mapfile -t journals < <(jq -r '.journals[]' "$cfg")

  for t in "${topics[@]}"; do
    for j in "${journals[@]}"; do
      search_papers "$t" "$j" "$days_back" "$max"
    done
  done

  log "Paper Catchup completed"
}

main
