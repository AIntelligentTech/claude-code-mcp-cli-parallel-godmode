#!/bin/bash
# Multi-Repository Git Status
# Fetches git status from multiple repositories in parallel
#
# Usage: ./multi-repo-status.sh /path/repo1 /path/repo2 /path/repo3

set -e

REPOS="$@"
OUTPUT_DIR="/tmp/multi-repo-status"

if [ -z "$REPOS" ]; then
  echo "Usage: $0 /path/repo1 /path/repo2 /path/repo3 ..."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "Fetching status for $(echo $REPOS | wc -w | tr -d ' ') repositories..."
echo ""

START=$(date +%s.%N)

# Launch parallel status checks
for repo in $REPOS; do
  repo_name=$(basename "$repo")
  (
    cd "$repo" 2>/dev/null && {
      echo "=== $repo_name ===" > "$OUTPUT_DIR/${repo_name}.txt"
      echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')" >> "$OUTPUT_DIR/${repo_name}.txt"
      echo "" >> "$OUTPUT_DIR/${repo_name}.txt"
      echo "Recent commits:" >> "$OUTPUT_DIR/${repo_name}.txt"
      git log --oneline -5 2>/dev/null >> "$OUTPUT_DIR/${repo_name}.txt" || echo "(no commits)" >> "$OUTPUT_DIR/${repo_name}.txt"
      echo "" >> "$OUTPUT_DIR/${repo_name}.txt"
      echo "Status:" >> "$OUTPUT_DIR/${repo_name}.txt"
      git status -s 2>/dev/null >> "$OUTPUT_DIR/${repo_name}.txt" || echo "(clean)" >> "$OUTPUT_DIR/${repo_name}.txt"
    } || echo "ERROR: $repo not found or not a git repo" > "$OUTPUT_DIR/${repo_name}.txt"
  ) &
done

wait

END=$(date +%s.%N)
TOTAL_TIME=$(echo "$END - $START" | bc)

echo "Completed in ${TOTAL_TIME}s"
echo ""

# Display results
for repo in $REPOS; do
  repo_name=$(basename "$repo")
  cat "$OUTPUT_DIR/${repo_name}.txt"
  echo ""
done
