#!/usr/bin/env bash
# Reply to one review thread, then resolve it. Resolve only happens if the
# reply lands.
#
# A cited SHA is proved to be IN THIS PR against GitHub, not against local
# remote-tracking refs: a stale tracking branch can still contain a commit the
# remote no longer has, and "contained by some remote branch" never meant
# "present in this PR".
#
# Usage:
#   respond.sh --repo <owner/repo> --pr <n> --thread <PRRT_id>
#              [--sha <sha>] [--note <text>] [--resolve] [--dry-run]
#
# Body is built for you: "Addressed <sha>" or "Addressed <sha> — <note>" or "<note>".
# The SHA is emitted bare so GitHub auto-links it.
set -euo pipefail

repo='' pr='' thread='' sha='' note='' resolve=0 dry=0

while [[ $# -gt 0 ]]; do
	case "$1" in
	--repo) repo="$2" && shift 2 ;;
	--pr) pr="$2" && shift 2 ;;
	--thread) thread="$2" && shift 2 ;;
	--sha) sha="$2" && shift 2 ;;
	--note) note="$2" && shift 2 ;;
	--resolve) resolve=1 && shift ;;
	--dry-run) dry=1 && shift ;;
	*) echo >&2 "respond.sh: unknown argument: $1" && exit 2 ;;
	esac
done

[[ -n "$thread" ]] || {
	echo >&2 "respond.sh: --thread is required"
	exit 2
}

if [[ -n "$sha" ]]; then
	sha="${sha//\`/}"
	[[ "$sha" =~ ^[0-9a-fA-F]{7,40}$ ]] || {
		echo >&2 "respond.sh: '$sha' is not a hex commit sha"
		exit 1
	}
	[[ "$repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || {
		echo >&2 "respond.sh: --repo <owner/repo> is required when citing a sha"
		exit 2
	}
	[[ "$pr" =~ ^[0-9]+$ ]] || {
		echo >&2 "respond.sh: --pr <number> is required when citing a sha"
		exit 2
	}

	head_oid=$(gh api "repos/${repo}/pulls/${pr}" --jq .head.sha) || {
		echo >&2 "respond.sh: could not read the head of ${repo}#${pr}"
		exit 1
	}

	# status describes head_oid relative to sha. "identical" or "ahead" means
	# sha is the PR head or an ancestor of it; anything else means the commit
	# is not in this PR.
	comparison=$(gh api "repos/${repo}/compare/${sha}...${head_oid}" 2>/dev/null) || {
		echo >&2 "respond.sh: $sha is not a commit GitHub can reach in ${repo}"
		exit 1
	}
	status=$(jq -r .status <<<"$comparison")
	case "$status" in
	identical | ahead) ;;
	*)
		echo >&2 "respond.sh: $sha is not in ${repo}#${pr} (compare says '$status') — refusing to claim it was addressed"
		exit 1
		;;
	esac

	full=$(jq -r .base_commit.sha <<<"$comparison")
	body="Addressed ${full:0:12}"
	[[ -n "$note" ]] && body="${body} — ${note}"
else
	[[ -n "$note" ]] || {
		echo >&2 "respond.sh: give --sha, --note, or both"
		exit 2
	}
	body="$note"
fi

if [[ "$dry" == 1 ]]; then
	printf '%s\treply=%s\tresolve=%s\n' "$thread" "$body" "$resolve"
	exit 0
fi

# shellcheck disable=SC2016  # $threadId/$body are GraphQL variables, not shell ones
gh api graphql -F threadId="$thread" -F body="$body" -f query='
  mutation($threadId:ID!,$body:String!){
    addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$threadId,body:$body}){
      comment{url}
    }
  }' --jq '.data.addPullRequestReviewThreadReply.comment.url'

if [[ "$resolve" == 1 ]]; then
	# shellcheck disable=SC2016  # GraphQL variable
	gh api graphql -F threadId="$thread" -f query='
    mutation($threadId:ID!){
      resolveReviewThread(input:{threadId:$threadId}){ thread{ id isResolved } }
    }' --jq '"resolved=" + (.data.resolveReviewThread.thread.isResolved|tostring)'
fi
