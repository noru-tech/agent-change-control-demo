#!/usr/bin/env bash
# Ask one model to review a diff. Prints the model's review on stdout.
#
#   scripts/review-model.sh anthropic|openai MODEL DIFF_FILE
#
# Environment: ANTHROPIC_API_KEY or OPENAI_API_KEY. The prompt is scripts/review-prompt.md;
# its sha256 is recorded in the signed review document as the instructions digest.

source "$(dirname "$0")/lib.sh"
need curl jq

vendor="${1:?usage: review-model.sh anthropic|openai MODEL DIFF_FILE}"
model="${2:?}"
diff_file="${3:?}"
prompt="$(cat "$ROOT/scripts/review-prompt.md")"$'\n\n```diff\n'"$(cat "$diff_file")"$'\n```'

case "$vendor" in
  anthropic)
    response="$(jq -n --arg model "$model" --arg prompt "$prompt" '{
        model: $model,
        max_tokens: 16000,
        fallbacks: "default",
        messages: [{role: "user", content: $prompt}]
      }' | curl -sS --fail-with-body https://api.anthropic.com/v1/messages \
        -H "content-type: application/json" \
        -H "x-api-key: ${ANTHROPIC_API_KEY:?}" \
        -H "anthropic-version: 2023-06-01" \
        -H "anthropic-beta: server-side-fallback-2026-07-01" \
        --data-binary @-)"
    stop="$(jq -r .stop_reason <<<"$response")"
    [ "$stop" != refusal ] || die "the model declined to review: $(jq -c .stop_details <<<"$response")"
    [ "$stop" = end_turn ] || die "unexpected stop_reason $stop"
    echo "model: $(jq -r .model <<<"$response")" >&2
    jq -r '.content[] | select(.type == "text") | .text' <<<"$response"
    ;;
  openai)
    response="$(jq -n --arg model "$model" --arg prompt "$prompt" '{
        model: $model,
        messages: [{role: "user", content: $prompt}]
      }' | curl -sS --fail-with-body https://api.openai.com/v1/chat/completions \
        -H "content-type: application/json" \
        -H "authorization: Bearer ${OPENAI_API_KEY:?}" \
        --data-binary @-)"
    finish="$(jq -r '.choices[0].finish_reason' <<<"$response")"
    [ "$finish" = stop ] || die "unexpected finish_reason $finish"
    echo "model: $(jq -r .model <<<"$response")" >&2
    jq -r '.choices[0].message.content' <<<"$response"
    ;;
  *) die "vendor must be anthropic or openai" ;;
esac
