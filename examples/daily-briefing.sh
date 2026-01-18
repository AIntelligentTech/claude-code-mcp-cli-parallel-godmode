#!/bin/bash
# Daily Briefing Data Gathering
# Fetches calendar, tasks, and email data in parallel
#
# Usage: ./daily-briefing.sh your@email.com

set -e

EMAIL="${1:-your@example.com}"
OUTPUT_DIR="${2:-/tmp/briefing}"

echo "Gathering daily briefing data for: $EMAIL"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Wave 1: Independent data sources (parallel)
echo "Wave 1: Fetching calendar, emails, and task lists..."
START=$(date +%s.%N)

mcp-cli call google-workspace/get_events "{
  \"user_google_email\": \"$EMAIL\",
  \"time_min\": \"$(date +%Y-%m-%d)\",
  \"time_max\": \"$(date -v+7d +%Y-%m-%d)\",
  \"max_results\": 50
}" > "$OUTPUT_DIR/events.json" 2>/dev/null &

mcp-cli call google-workspace/search_gmail_messages "{
  \"user_google_email\": \"$EMAIL\",
  \"query\": \"in:inbox newer_than:3d\",
  \"page_size\": 20
}" > "$OUTPUT_DIR/emails.json" 2>/dev/null &

mcp-cli call google-workspace/list_task_lists "{
  \"user_google_email\": \"$EMAIL\"
}" > "$OUTPUT_DIR/task_lists.json" 2>/dev/null &

wait
END=$(date +%s.%N)
WAVE1_TIME=$(echo "$END - $START" | bc)
echo "Wave 1 complete: ${WAVE1_TIME}s"

# Extract task list IDs
TODAY_ID=$(cat "$OUTPUT_DIR/task_lists.json" | tr -d '\n' | grep -o 'Today (ID: [^)]*' | head -1 | sed 's/Today (ID: //' || echo "")
FLAGGED_ID=$(cat "$OUTPUT_DIR/task_lists.json" | tr -d '\n' | grep -o 'Flagged (ID: [^)]*' | head -1 | sed 's/Flagged (ID: //' || echo "")

# Wave 2: Fetch tasks from each list (parallel)
echo ""
echo "Wave 2: Fetching task details..."
START=$(date +%s.%N)

if [ -n "$TODAY_ID" ]; then
  mcp-cli call google-workspace/list_tasks "{
    \"user_google_email\": \"$EMAIL\",
    \"task_list_id\": \"$TODAY_ID\",
    \"show_completed\": false,
    \"max_results\": 50
  }" > "$OUTPUT_DIR/tasks_today.json" 2>/dev/null &
fi

if [ -n "$FLAGGED_ID" ]; then
  mcp-cli call google-workspace/list_tasks "{
    \"user_google_email\": \"$EMAIL\",
    \"task_list_id\": \"$FLAGGED_ID\",
    \"show_completed\": false,
    \"max_results\": 50
  }" > "$OUTPUT_DIR/tasks_flagged.json" 2>/dev/null &
fi

wait
END=$(date +%s.%N)
WAVE2_TIME=$(echo "$END - $START" | bc)
echo "Wave 2 complete: ${WAVE2_TIME}s"

# Summary
echo ""
echo "=== BRIEFING DATA GATHERED ==="
echo "Total time: $(echo "$WAVE1_TIME + $WAVE2_TIME" | bc)s"
echo ""
echo "Files created:"
ls -la "$OUTPUT_DIR"/*.json 2>/dev/null || echo "  (no files)"
echo ""
echo "=== CALENDAR EVENTS ==="
jq -r '.content[0].text' "$OUTPUT_DIR/events.json" 2>/dev/null | head -20 || echo "(no events)"
echo ""
echo "=== TODAY'S TASKS ==="
jq -r '.content[0].text' "$OUTPUT_DIR/tasks_today.json" 2>/dev/null | head -20 || echo "(no tasks)"
echo ""
echo "=== FLAGGED ITEMS ==="
jq -r '.content[0].text' "$OUTPUT_DIR/tasks_flagged.json" 2>/dev/null | head -20 || echo "(no flagged items)"
