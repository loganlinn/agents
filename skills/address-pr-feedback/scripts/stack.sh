#!/usr/bin/env bash
# Enumerate the PR stack around a target PR and report each branch's
# outstanding feedback and review-request status. Read-only.
#
# The stack is derived from base/head links on GitHub, not from a stacking
# tool's local metadata, so it works for Graphite, git-spice, and hand-built
# stacks alike, and reflects what reviewers actually see.
#
# Usage: stack.sh --repo <owner/repo> --pr <n>
set -euo pipefail

repo='' pr='' max_depth=25

while [[ $# -gt 0 ]]; do
	case "$1" in
	--repo) repo="$2" && shift 2 ;;
	--pr) pr="$2" && shift 2 ;;
	*) echo >&2 "stack.sh: unknown argument: $1" && exit 2 ;;
	esac
done

[[ "$repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || {
	echo >&2 "stack.sh: --repo <owner/repo> is required"
	exit 2
}
[[ "$pr" =~ ^[0-9]+$ ]] || {
	echo >&2 "stack.sh: --pr <number> is required"
	exit 2
}

safe_ref() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._/@+-]*$ && "$1" != *..* ]]; }

target=$(gh pr view "$pr" --repo "$repo" --json number,headRefName,baseRefName)
target_head=$(jq -r .headRefName <<<"$target")
target_base=$(jq -r .baseRefName <<<"$target")

# Ancestors: follow base links down toward trunk.
ancestors=()
cur="$target_base"
for ((i = 0; i < max_depth; i++)); do
	safe_ref "$cur" || break
	parent=$(gh pr list --repo "$repo" --state open --head "$cur" --limit 1 --json number,baseRefName)
	[[ "$(jq -r 'length' <<<"$parent")" == "0" ]] && break
	ancestors=("$(jq -r '.[0].number' <<<"$parent")" "${ancestors[@]}")
	cur=$(jq -r '.[0].baseRefName' <<<"$parent")
done

# Descendants: follow head links up. A branch may have several children.
descendants=()
frontier=("$target_head")
for ((i = 0; i < max_depth; i++)); do
	[[ ${#frontier[@]} -eq 0 ]] && break
	next=()
	for h in "${frontier[@]}"; do
		safe_ref "$h" || continue
		kids=$(gh pr list --repo "$repo" --state open --base "$h" --limit 20 --json number,headRefName)
		while read -r n; do
			[[ -z "$n" ]] && continue
			descendants+=("$n")
		done < <(jq -r '.[].number' <<<"$kids")
		while read -r hh; do
			[[ -z "$hh" ]] && continue
			next+=("$hh")
		done < <(jq -r '.[].headRefName' <<<"$kids")
	done
	frontier=(${next+"${next[@]}"})
done

order=(${ancestors+"${ancestors[@]}"} "$pr" ${descendants+"${descendants[@]}"})

read -r -d '' q <<'GRAPHQL' || true
query($owner:String!,$repo:String!,$pr:Int!){
  viewer{login}
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      number title url isDraft baseRefName headRefName reviewDecision
      mergeable
      reviewRequests(first:20){nodes{requestedReviewer{
        ... on User{login} ... on Team{slug} ... on Bot{login}
      }}}
      latestReviews(first:50){nodes{author{login} state}}
      reviewThreads(first:100){nodes{
        isResolved
        lastComment:comments(last:1){nodes{author{login}}}
      }}
    }
  }
}
GRAPHQL

owner="${repo%%/*}"
name="${repo##*/}"

rows='[]'
for n in "${order[@]}"; do
	node=$(gh api graphql -F owner="$owner" -F repo="$name" -F pr="$n" -f query="$q")
	row=$(jq --argjson target "$pr" '
    (.data.viewer.login) as $me |
    .data.repository.pullRequest |
    {
      number, title, url, isDraft, reviewDecision, mergeable,
      head: .headRefName, base: .baseRefName,
      isTarget: (.number == $target),
      requestedReviewers: [.reviewRequests.nodes[].requestedReviewer | (.login // .slug) | select(. != null)],
      changesRequestedBy: [.latestReviews.nodes[] | select(.state == "CHANGES_REQUESTED") | .author.login],
      unresolved: ([.reviewThreads.nodes[] | select(.isResolved | not)] | length),
      awaitingReviewer: ([.reviewThreads.nodes[]
        | select(.isResolved | not)
        | select((.lastComment.nodes[0].author.login // "") == $me)] | length)
    }
    | . + { needsYou: (.unresolved - .awaitingReviewer) }
  ' <<<"$node")
	rows=$(jq --argjson r "$row" '. + [$r]' <<<"$rows")
done

jq -n --argjson rows "$rows" --argjson target "$pr" '
  {
    target: $target,
    size: ($rows | length),
    isStack: (($rows | length) > 1),
    prs: $rows,
    totals: {
      unresolved: ([$rows[].unresolved] | add // 0),
      needsYou: ([$rows[].needsYou] | add // 0),
      changesRequested: ([$rows[] | select((.changesRequestedBy | length) > 0)] | length)
    }
  }'
