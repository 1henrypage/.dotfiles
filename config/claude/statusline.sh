#!/bin/bash
input=$(cat)

MODEL_ID=$(echo "$input" | jq -r '.model.id')
MODEL_NAME=$(echo "$input" | jq -r '.model.display_name')

USED=$(echo "$input" | jq -r '((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0))')
TOTAL=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
COST_FMT=$(printf '$%.2f' "$COST")

EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
THINKING=$(echo "$input" | jq -r 'if .thinking.enabled == true then "on" elif .thinking.enabled == false then "off" else empty end')

LINE="[$MODEL_ID | $MODEL_NAME] ${COST_FMT} | ${USED}/${TOTAL} (${PCT}%)"
[ -n "$EFFORT" ] && LINE="$LINE | effort: $EFFORT"
[ -n "$THINKING" ] && LINE="$LINE | thinking: $THINKING"

echo "$LINE"
