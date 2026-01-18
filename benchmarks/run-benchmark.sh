#!/bin/bash
# MCP Parallel Orchestration Benchmark
# Compares sequential vs parallel mcp-cli execution
#
# Usage: ./run-benchmark.sh your@email.com

set -e

EMAIL="${1:-your@example.com}"
ITERATIONS="${2:-1}"

echo "MCP Parallel Orchestration Benchmark"
echo "====================================="
echo "Email: $EMAIL"
echo "Iterations: $ITERATIONS"
echo ""

# Check prerequisites
if [ "${ENABLE_EXPERIMENTAL_MCP_CLI}" != "true" ]; then
  echo "ERROR: ENABLE_EXPERIMENTAL_MCP_CLI must be set to 'true'"
  echo "Run: export ENABLE_EXPERIMENTAL_MCP_CLI=true"
  exit 1
fi

if ! command -v mcp-cli &> /dev/null; then
  echo "ERROR: mcp-cli not found"
  echo "Ensure you're running this from within a Claude Code session"
  exit 1
fi

echo "Verifying MCP connection..."
mcp-cli servers | head -3
echo ""

# Test function
run_sequential() {
  local email="$1"
  START=$(date +%s.%N)
  mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$email\"}" > /dev/null 2>&1
  mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$email\"}" > /dev/null 2>&1
  mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$email\"}" > /dev/null 2>&1
  mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$email\"}" > /dev/null 2>&1
  mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$email\"}" > /dev/null 2>&1
  END=$(date +%s.%N)
  echo "$END - $START" | bc
}

run_parallel() {
  local email="$1"
  START=$(date +%s.%N)
  mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$email\"}" > /dev/null 2>&1 &
  mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$email\"}" > /dev/null 2>&1 &
  mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$email\"}" > /dev/null 2>&1 &
  mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$email\"}" > /dev/null 2>&1 &
  mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$email\"}" > /dev/null 2>&1 &
  wait
  END=$(date +%s.%N)
  echo "$END - $START" | bc
}

# Run benchmarks
echo "Running benchmark ($ITERATIONS iteration(s))..."
echo ""

SEQ_TOTAL=0
PAR_TOTAL=0

for i in $(seq 1 $ITERATIONS); do
  echo "Iteration $i:"

  echo -n "  Sequential (5 calls): "
  SEQ_TIME=$(run_sequential "$EMAIL")
  echo "${SEQ_TIME}s"
  SEQ_TOTAL=$(echo "$SEQ_TOTAL + $SEQ_TIME" | bc)

  echo -n "  Parallel (5 calls):   "
  PAR_TIME=$(run_parallel "$EMAIL")
  echo "${PAR_TIME}s"
  PAR_TOTAL=$(echo "$PAR_TOTAL + $PAR_TIME" | bc)

  SPEEDUP=$(echo "scale=2; $SEQ_TIME / $PAR_TIME" | bc)
  echo "  Speedup: ${SPEEDUP}x"
  echo ""
done

# Calculate averages if multiple iterations
if [ "$ITERATIONS" -gt 1 ]; then
  SEQ_AVG=$(echo "scale=3; $SEQ_TOTAL / $ITERATIONS" | bc)
  PAR_AVG=$(echo "scale=3; $PAR_TOTAL / $ITERATIONS" | bc)
  AVG_SPEEDUP=$(echo "scale=2; $SEQ_AVG / $PAR_AVG" | bc)

  echo "=== AVERAGE RESULTS ==="
  echo "Sequential: ${SEQ_AVG}s"
  echo "Parallel:   ${PAR_AVG}s"
  echo "Speedup:    ${AVG_SPEEDUP}x"
else
  SPEEDUP=$(echo "scale=2; $SEQ_TIME / $PAR_TIME" | bc)
  echo "=== RESULTS ==="
  echo "Sequential: ${SEQ_TIME}s"
  echo "Parallel:   ${PAR_TIME}s"
  echo "Speedup:    ${SPEEDUP}x"
fi

echo ""
echo "Benchmark complete."
