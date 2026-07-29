#!/usr/bin/env bash
# Collect every open feedback loop on a PR as one normalized JSON document.
# Read-only. Usage: collect.sh [pr-number|url|branch]  (default: current branch's PR)
set -euo pipefail

pr_ref="${1:-}"

if [[ -z "$pr_ref" ]]; then
	pr_json=$(gh pr view --json number,url,title,headRefName,baseRefName,isDraft,mergeable,mergeStateStatus,headRepositoryOwner,headRepository)
else
	pr_json=$(gh pr view "$pr_ref" --json number,url,title,headRefName,baseRefName,isDraft,mergeable,mergeStateStatus,headRepositoryOwner,headRepository)
fi

number=$(jq -r .number <<<"$pr_json")
url=$(jq -r .url <<<"$pr_json")
owner=$(sed -E 's#https://[^/]+/([^/]+)/([^/]+)/pull/.*#\1#' <<<"$url")
repo=$(sed -E 's#https://[^/]+/([^/]+)/([^/]+)/pull/.*#\2#' <<<"$url")
slug="${owner}/${repo}"

# A PR URL can name a different repo than the worktree we are standing in.
# Record that so the caller can refuse to apply fixes across repos.
worktree_slug=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || echo '')

read -r -d '' query <<'GRAPHQL' || true
query($owner:String!,$repo:String!,$pr:Int!,$cursor:String){
  viewer{login}
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      reviewDecision
      reviewThreads(first:50,after:$cursor){
        pageInfo{hasNextPage endCursor}
        nodes{
          id isResolved isOutdated path line originalLine
          comments(first:100){
            pageInfo{hasNextPage}
            nodes{ databaseId url createdAt author{login} authorAssociation body }
          }
          # Authoritative regardless of how long the thread is. Deciding who
          # spoke last from a truncated page is how an agent talks over the user.
          lastComment:comments(last:1){nodes{author{login} createdAt}}
        }
      }
      reviews(first:100){pageInfo{hasNextPage} nodes{author{login} state submittedAt url body}}
      latestReviews:latestReviews(first:100){nodes{author{login} state submittedAt url}}
      comments(first:100){pageInfo{hasNextPage} nodes{author{login} createdAt url body}}
    }
  }
}
GRAPHQL

cursor=null
threads='[]'
base=''
while :; do
	page=$(gh api graphql -F owner="$owner" -F repo="$repo" -F pr="$number" -F cursor="$cursor" -f query="$query")
	[[ -z "$base" ]] && base="$page"
	threads=$(jq -s '.[0] + .[1]' <<<"$threads
$(jq '.data.repository.pullRequest.reviewThreads.nodes' <<<"$page")")
	has_next=$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage' <<<"$page")
	[[ "$has_next" == "true" ]] || break
	cursor=$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor' <<<"$page")
done

# Files touched by this PR — anything outside this list is out of scope for a
# fix, so an empty list must never be a silent stand-in for a failed lookup.
if ! diff_files=$(gh pr diff "$number" --repo "$slug" --name-only 2>&1); then
	echo >&2 "collect.sh: could not read the diff of ${slug}#${number}: ${diff_files}"
	exit 1
fi
files=$(jq -R . <<<"$diff_files" | jq -s '[.[] | select(length > 0)]')

jq -n \
	--argjson pr "$pr_json" \
	--argjson base "$base" \
	--argjson threads "$threads" \
	--argjson files "$files" \
	--arg slug "$slug" --arg worktreeSlug "$worktree_slug" \
	'
  ($base.data.viewer.login) as $me |
  ($base.data.repository.pullRequest) as $p |
  {
    pr: ($pr + {reviewDecision: $p.reviewDecision, repo: $slug}),
    me: $me,
    worktreeRepo: (if $worktreeSlug == "" then null else $worktreeSlug end),
    repoMatchesWorktree: ($worktreeSlug == $slug),
    changedFiles: $files,
    latestReviewByAuthor: (
      [$p.latestReviews.nodes[] | select(.author.login != $me)]
      | map({key: .author.login, value: {state, submittedAt, url}}) | from_entries
    ),
    reviewBodies: [
      $p.reviews.nodes[]
      | select(.author.login != $me) | select((.body // "") | length > 0)
      | {author: .author.login, state, url, body}
    ],
    issueComments: [
      $p.comments.nodes[] | select(.author.login != $me)
      | {author: .author.login, url, body}
    ],
    # A stack comment posted by the PR author is the signal that a stacking
    # tool owns this branch, so branch operations must go through that tool.
    stack: (
      [ $p.comments.nodes[]
        | select(.author.login == $me)
        | select((.body // "") | test("managed by Graphite|app\\.graphite\\.com|part of the following stack|git-?spice"; "i"))
        | {
            tool: (
              if ((.body // "") | test("graphite"; "i")) then "graphite"
              elif ((.body // "") | test("git-?spice"; "i")) then "git-spice"
              else "unknown"
              end
            ),
            url: .url
          }
      ] | first // null
    ),
    threads: [
      $threads[]
      | {
          id, path, isResolved, isOutdated,
          line: (.line // .originalLine),
          author: (.comments.nodes[0].author.login // "unknown"),
          rootCommentId: (.comments.nodes[0].databaseId),
          url: (.comments.nodes[0].url),
          lastAuthor: (.lastComment.nodes[0].author.login // "unknown"),
          awaitingReviewer: ((.lastComment.nodes[0].author.login // "") == $me),
          commentsTruncated: (.comments.pageInfo.hasNextPage // false),
          hasSuggestion: ([.comments.nodes[].body | select(test("```suggestion"))] | length > 0),
          comments: [.comments.nodes[] | {author: .author.login, body}]
        }
    ],
    # Any incomplete connection means a triage decision could rest on data
    # that was silently cut off. Treat a non-empty list as a blocker.
    incomplete: (
      []
      + (if ($p.reviews.pageInfo.hasNextPage // false) then ["reviews"] else [] end)
      + (if ($p.comments.pageInfo.hasNextPage // false) then ["issue comments"] else [] end)
      + ([$threads[] | select(.comments.pageInfo.hasNextPage // false) | "thread \(.id) comments"])
    ),
    counts: {
      threadsTotal: ($threads | length),
      threadsUnresolved: ([$threads[] | select(.isResolved | not)] | length)
    }
  }'
