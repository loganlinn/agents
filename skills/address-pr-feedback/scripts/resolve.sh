#!/usr/bin/env bash
# Resolve one review thread without posting a reply.
#
# Usage: resolve.sh --thread <PRRT_id> [--dry-run]
set -euo pipefail

thread='' dry=0

while [[ $# -gt 0 ]]; do
	case "$1" in
	--thread) thread="$2" && shift 2 ;;
	--dry-run) dry=1 && shift ;;
	*) echo >&2 "resolve.sh: unknown argument: $1" && exit 2 ;;
	esac
done

[[ -n "$thread" ]] || {
	echo >&2 "resolve.sh: --thread is required"
	exit 2
}

if [[ "$dry" == 1 ]]; then
	printf '%s\tresolve=true\n' "$thread"
	exit 0
fi

# shellcheck disable=SC2016  # $threadId is a GraphQL variable, not a shell one.
gh api graphql -F threadId="$thread" -f query='
  mutation($threadId:ID!){
    resolveReviewThread(input:{threadId:$threadId}){ thread{ id isResolved } }
  }' --jq '"resolved=" + (.data.resolveReviewThread.thread.isResolved|tostring)'
