#!/usr/bin/env bash
# Report whether THIS worktree can safely take new commits for a PR, and what
# syncing it needs first. Touches remote-tracking refs only (git fetch); never
# the index, the working tree, or any branch.
#
# Emits a STRUCTURED sync action, never a command string: ref names are
# attacker-controlled input on a fork PR, and git permits '$', '(' and ')' in
# them. Refs are validated here and passed as data, never as shell text.
#
# Usage: preflight.sh --head <pr-head-branch> --base <pr-base-branch> [--no-fetch]
set -euo pipefail

head_branch='' base_branch='' do_fetch=1

while [[ $# -gt 0 ]]; do
	case "$1" in
	--head) head_branch="$2" && shift 2 ;;
	--base) base_branch="$2" && shift 2 ;;
	--no-fetch) do_fetch=0 && shift ;;
	*) echo >&2 "preflight.sh: unknown argument: $1" && exit 2 ;;
	esac
done

# Conservative ref charset. Anything outside it is refused rather than escaped.
safe_ref() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._/@+-]*$ && "$1" != *..* ]]; }

unsafe_refs=()
for r in "$head_branch" "$base_branch"; do
	[[ -n "$r" ]] && ! safe_ref "$r" && unsafe_refs+=("$r")
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
	echo >&2 "preflight.sh: not inside a git worktree"
	exit 1
}

toplevel=$(git rev-parse --show-toplevel)
gitdir=$(git rev-parse --absolute-git-dir)
common=$(git rev-parse --path-format=absolute --git-common-dir)
branch=$(git rev-parse --abbrev-ref HEAD)
detached=false
[[ "$branch" == "HEAD" ]] && detached=true
safe_ref "$branch" || unsafe_refs+=("$branch")

# Fail closed: stale remote refs make every ahead/behind count a lie.
fetch_ok=true
if [[ "$do_fetch" == 1 ]]; then
	git fetch --quiet origin 2>/dev/null || fetch_ok=false
else
	fetch_ok=false
fi

in_progress=null
if [[ -e "$gitdir/MERGE_HEAD" ]]; then
	in_progress='"merge"'
elif [[ -d "$gitdir/rebase-merge" || -d "$gitdir/rebase-apply" ]]; then
	in_progress='"rebase"'
elif [[ -e "$gitdir/CHERRY_PICK_HEAD" ]]; then
	in_progress='"cherry-pick"'
elif [[ -e "$gitdir/REVERT_HEAD" ]]; then
	in_progress='"revert"'
elif [[ -e "$gitdir/BISECT_LOG" ]]; then
	in_progress='"bisect"'
fi

upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo '')
behind_up=0 ahead_up=0
if [[ -n "$upstream" ]]; then
	read -r behind_up ahead_up < <(git rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || echo "0 0")
fi

# The PR's base is authoritative. On a stack it is the parent branch, not trunk.
# An unresolvable base is a blocker, never a zero gap.
base_ref='' behind_base=0 base_resolved=true
if [[ -n "$base_branch" ]]; then
	if safe_ref "$base_branch" && git rev-parse --verify --quiet "origin/${base_branch}" >/dev/null 2>&1; then
		base_ref="origin/${base_branch}"
		behind_base=$(git rev-list --count "HEAD..${base_ref}" 2>/dev/null || echo 0)
	else
		base_resolved=false
	fi
fi

to_json_array() { jq -R . | jq -s .; }

staged=$(git diff --cached --name-only | to_json_array)
dirty=$(git diff --name-only | to_json_array)
untracked=$(git ls-files --others --exclude-standard | to_json_array)
worktrees=$(git worktree list --porcelain | awk '/^worktree /{print $2}' | to_json_array)
unsafe=$(printf '%s\n' ${unsafe_refs+"${unsafe_refs[@]}"} | { grep -v '^$' || true; } | to_json_array)

stack_tool='null'
[[ -e "$common/.graphite_repo_config" ]] && stack_tool='"graphite"'
[[ -e "$common/spice.db" || -d "$common/spice" ]] && stack_tool='"git-spice"'

jq -n \
	--arg toplevel "$toplevel" --arg branch "$branch" \
	--arg head "$head_branch" --arg base "$base_branch" --arg baseRef "$base_ref" \
	--arg upstream "$upstream" --argjson detached "$detached" \
	--argjson inProgress "$in_progress" --argjson stackTool "$stack_tool" \
	--argjson staged "$staged" --argjson dirty "$dirty" --argjson untracked "$untracked" \
	--argjson aheadUpstream "$ahead_up" --argjson behindUpstream "$behind_up" \
	--argjson behindBase "$behind_base" --argjson worktrees "$worktrees" \
	--argjson fetchOk "$fetch_ok" --argjson baseResolved "$base_resolved" \
	--argjson unsafeRefs "$unsafe" \
	'
  {
    worktree: $toplevel, branch: $branch, detached: $detached,
    onExpectedBranch: (if $head == "" then null else ($branch == $head) end),
    baseBranch: (if $base == "" then null else $base end),
    baseRef: (if $baseRef == "" then null else $baseRef end),
    baseRefResolved: $baseResolved,
    upstreamRef: (if $upstream == "" then null else $upstream end),
    aheadUpstream: $aheadUpstream, behindUpstream: $behindUpstream,
    behindBase: $behindBase,
    fetchOk: $fetchOk,
    unsafeRefNames: $unsafeRefs,
    inProgress: $inProgress,
    localStackTool: $stackTool,
    stagedFiles: $staged, dirtyFiles: $dirty, untrackedFiles: $untracked,
    otherWorktrees: ($worktrees | length)
  }
  | . + { syncRequired: (.behindBase > 0 or .behindUpstream > 0) }
  # A rebase refuses to run against a dirty index or working tree, and cannot
  # run at all mid-operation. These are facts about git, not preferences.
  | . + {
      rebaseBlockedBy: (
        []
        + (if .inProgress != null then ["\(.inProgress) in progress"] else [] end)
        + (if (.stagedFiles | length) > 0 then ["\(.stagedFiles|length) staged file(s) in the index"] else [] end)
        + (if (.dirtyFiles | length) > 0 then ["\(.dirtyFiles|length) modified file(s) in the working tree"] else [] end)
      )
    }
  | . + { rebaseable: ((.rebaseBlockedBy | length) == 0 and (.detached | not)) }
  | . + {
      blockers: (
        []
        + (if (.unsafeRefNames | length) > 0
             then ["ref name(s) outside the safe charset: \(.unsafeRefNames | join(", ")) — refuse to run git commands against these"]
             else [] end)
        + (if .fetchOk | not then ["could not fetch origin — every ahead/behind count below is unverified"] else [] end)
        + (if .baseRefResolved | not then ["PR base \($base) does not resolve to a remote ref — the gap to base is unknown, not zero"] else [] end)
        + (if .inProgress != null then ["\(.inProgress) in progress — finish or abort it first"] else [] end)
        + (if .detached then ["HEAD is detached — the PR branch is not checked out here"] else [] end)
        + (if .onExpectedBranch == false then ["this worktree is on \(.branch), the PR head is \($head)"] else [] end)
        + (if (.stagedFiles | length) > 0 then ["index already has \(.stagedFiles|length) staged file(s) — a commit here would sweep them in"] else [] end)
        + (if .syncRequired and (.rebaseable | not)
             then ["needs syncing (\(.behindBase) behind base, \(.behindUpstream) behind upstream) but cannot be rebased: \(.rebaseBlockedBy | join("; "))"]
             else [] end)
        + (if .aheadUpstream > 0
             then ["\(.aheadUpstream) local commit(s) not yet pushed — a push would publish them alongside the fixes"]
             else [] end)
      )
    }
  # Structured, never a command string. Any blocker wins, so the action can
  # never contradict the blocker list.
  | . + {
      sync: {
        action: (
          if (.blockers | length) > 0 then "blocked"
          elif (.syncRequired | not) then "none"
          elif .behindUpstream > 0 and .aheadUpstream == 0 then "fast-forward"
          elif .behindUpstream > 0 then "rebase-onto-upstream"
          else "rebase-onto-base"
          end
        ),
        upstreamRef: .upstreamRef,
        baseRef: .baseRef
      }
    }'
