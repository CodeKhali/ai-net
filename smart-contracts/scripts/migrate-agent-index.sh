#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: STELLAR_SECRET_KEY=... STELLAR_NETWORK=testnet $0 <contract-id> [batch-size]" >&2
}

if [[ $# -lt 1 || -z "${STELLAR_SECRET_KEY:-}" ]]; then
  usage
  exit 1
fi

CONTRACT_ID="$1"
BATCH_SIZE="${2:-50}"
NETWORK="${STELLAR_NETWORK:-testnet}"

if [[ ! "$BATCH_SIZE" =~ ^[1-9][0-9]*$ ]] || (( BATCH_SIZE > 50 )); then
  echo "batch-size must be an integer between 1 and 50" >&2
  exit 1
fi

invoke() {
  stellar contract invoke \
    --network "$NETWORK" \
    --source-account "$STELLAR_SECRET_KEY" \
    --id "$CONTRACT_ID" \
    -- "$@"
}

TOTAL_OUTPUT="$(invoke registration_sequence)"
TOTAL="$(printf '%s' "$TOTAL_OUTPUT" | grep -oE '[0-9]+' | tail -n 1)"
if [[ ! "$TOTAL" =~ ^[0-9]+$ ]]; then
  echo "Could not read registration_sequence from contract: $TOTAL_OUTPUT" >&2
  exit 1
fi

CURSOR=0
while (( CURSOR < TOTAL )); do
  echo "Migrating registration slots $CURSOR-$((CURSOR + BATCH_SIZE - 1)) of $TOTAL"
  invoke migrate_agent_index --cursor "$CURSOR" --limit "$BATCH_SIZE" >/dev/null
  CURSOR=$((CURSOR + BATCH_SIZE))
done

echo "Agent index migration complete: $TOTAL registration slots processed."