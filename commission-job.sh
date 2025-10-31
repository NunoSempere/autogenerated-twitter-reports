#!/bin/bash

FILTER_QUESTION="$1"
SUMMARIZATION_QUESTION="$2"
LIST="$3"
FILENAME="$4"
WEEK=$(date +%V)
LOGS="$WEEK/full/$FILENAME.log"
OUTPUT_FULL="$WEEK/full/$FILENAME.full"
OUTPUT_MD="$WEEK/$FILENAME.md"

mkdir -p $WEEK
mkdir -p $WEEK/full

# Instructions

if [ -z "$FILTER_QUESTION" ] || [ -z "$SUMMARIZATION_QUESTION" ] || [ -z "$LIST" ]; then
    echo "Usage: $0 <filter_question> <summarization_question> <list_name>"
    echo "Example: $0 'Does this tweet discuss AI?' 'What are the main AI developments?' 'ai-og'"
    exit 1
fi

# Create JSON payload using jq to properly escape values
JSON_PAYLOAD=$(jq -n \
  --arg filter_question "$FILTER_QUESTION" \
  --arg summarization_question "$SUMMARIZATION_QUESTION" \
  --arg list "$LIST" \
  '{
    "filter_question": $filter_question,
    "summarization_question": $summarization_question,
    "list": $list
  }')

JOB_RESPONSE=$(curl -X POST https://tweets.nunosempere.com/api/filter-job \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD")

# Extract job ID
JOB_ID=$(echo $JOB_RESPONSE | jq -r '.data.job_id')
echo "Created job: $JOB_ID"

# 2. Poll for status until complete
while true; do
  STATUS=$(curl -s "https://tweets.nunosempere.com/api/filter-job/$JOB_ID/status")
  CURRENT_STATUS=$(echo $STATUS | jq -r '.data.status')
  
  echo "Status: $CURRENT_STATUS"
  
  if [ "$CURRENT_STATUS" = "completed" ]; then
    echo "Job completed!"
    break
  elif [ "$CURRENT_STATUS" = "failed" ]; then
    echo "Job failed: $(echo $STATUS | jq -r '.data.error_message')"
    exit 1
  fi
  
  # Show progress
  echo $STATUS | jq '.data.progress'
  
  sleep 2
done

# 3. Get results

curl "https://tweets.nunosempere.com/api/filter-job/$JOB_ID/results" | jq | tee "$OUTPUT_FULL"

cat "$OUTPUT_FULL" | jq -r .data.results.summary > "$OUTPUT_MD"

