#!/usr/bin/env bash
# Ask an OpenAI model to review a diff (scenario 10). Prints the model's review on stdout and the
# model that served it on stderr.
#
#   scripts/review-model.sh MODEL DIFF_FILE
#
# Environment: OPENAI_API_KEY. The prompt is scripts/review-prompt.md; its sha256 is recorded in
# the signed review document as the instructions digest.

source "$(dirname "$0")/lib.sh"
need curl jq

model="${1:?usage: review-model.sh MODEL DIFF_FILE}"
diff_file="${2:?}"
prompt="$(cat "$ROOT/scripts/review-prompt.md")"$'\n\n```diff\n'"$(cat "$diff_file")"$'\n```'

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
