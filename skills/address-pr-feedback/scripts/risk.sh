#!/usr/bin/env bash
# Size the regression risk of the commits made during this run, before pushing.
# Read-only.
#
# The verdict is mechanical on purpose: `high` iff a hard trigger fired. Raw
# diff size never stops a push on its own, because a gate that fires on every
# run destroys the velocity the skill exists to protect.
#
# Usage:
#   risk.sh --since <sha-before-my-commits>
#           --changed-files '<json array from collect.sh .changedFiles>'
#           --verification <passed|failed|none>
#           [--diverged <thread-id,...>]
#           [--tripwire-glob <glob>]      (repeatable, adds to defaults)
#           [--accept-unverified <glob>]  (repeatable)
set -euo pipefail

since='' changed_files='[]' verification='' diverged=''
extra_tripwires=() accept_unverified=()

while [[ $# -gt 0 ]]; do
	case "$1" in
	--since) since="$2" && shift 2 ;;
	--changed-files) changed_files="$2" && shift 2 ;;
	--verification) verification="$2" && shift 2 ;;
	--diverged) diverged="$2" && shift 2 ;;
	--tripwire-glob) extra_tripwires+=("$2") && shift 2 ;;
	--accept-unverified) accept_unverified+=("$2") && shift 2 ;;
	*) echo >&2 "risk.sh: unknown argument: $1" && exit 2 ;;
	esac
done

[[ "$since" =~ ^[0-9a-fA-F]{7,40}$ ]] || {
	echo >&2 "risk.sh: --since <sha> is required (the commit HEAD was at before this run)"
	exit 2
}
case "$verification" in
passed | failed | none) ;;
*)
	echo >&2 "risk.sh: --verification must be passed, failed, or none"
	exit 2
	;;
esac
git rev-parse --verify --quiet "${since}^{commit}" >/dev/null || {
	echo >&2 "risk.sh: $since is not a commit in this repo"
	exit 1
}

# Paths the repo itself documents as load-bearing. Kept in sync with the
# repo's own conventions rather than forming a parallel taxonomy.
tripwires=(
	'*/generated/*' 'generated/*' '*.gen.ts'
	'packages/server/src/data-deletion/s3-coverage/s3-bucket-registry.ts'
	'security.md' '*/security.md'
	'packages/server/src/public-api/openapi.yaml'
	'*OPENAPI-CHANGELOG.md'
	'*/migrations/*' 'migrations/*'
	'.github/workflows/*'
	'yarn.lock' 'bun.lock' 'pnpm-lock.yaml' 'package-lock.json'
	'*/messages.po'
)
tripwires+=(${extra_tripwires+"${extra_tripwires[@]}"})

matches_any() {
	local f="$1" p
	shift
	for p in "$@"; do
		# shellcheck disable=SC2053  # glob match is the intent
		[[ "$f" == $p ]] && return 0
	done
	return 1
}

is_docs() {
	case "$1" in
	*.md | *.mdx | *.txt | docs/* | */docs/* | LICENSE*) return 0 ;;
	*) return 1 ;;
	esac
}

mapfile -t touched < <(git diff --name-only "${since}..HEAD")
commits=$(git rev-list --count "${since}..HEAD")
read -r insertions deletions < <(
	git diff --numstat "${since}..HEAD" |
		awk '{i+=$1; d+=$2} END {print (i==""?0:i), (d==""?0:d)}'
)

out_of_scope=() tripped=() behavior=()
for f in ${touched+"${touched[@]}"}; do
	[[ -z "$f" ]] && continue
	jq -e --arg f "$f" 'index($f) != null' <<<"$changed_files" >/dev/null 2>&1 ||
		out_of_scope+=("$f")
	matches_any "$f" "${tripwires[@]}" && tripped+=("$f")
	is_docs "$f" || behavior+=("$f")
done

# A behaviour-bearing file the caller explicitly accepts as unverifiable does
# not count toward the unverified trigger.
unverified=()
for f in ${behavior+"${behavior[@]}"}; do
	if [[ ${#accept_unverified[@]} -gt 0 ]] && matches_any "$f" "${accept_unverified[@]}"; then
		continue
	fi
	unverified+=("$f")
done

to_json_array() { jq -R . | jq -s .; }
arr() { printf '%s\n' ${1+"$@"} | { grep -v '^$' || true; } | to_json_array; }

jq -n \
	--arg since "$since" --arg verification "$verification" --arg diverged "$diverged" \
	--argjson commits "$commits" --argjson insertions "$insertions" --argjson deletions "$deletions" \
	--argjson touched "$(arr ${touched+"${touched[@]}"})" \
	--argjson outOfScope "$(arr ${out_of_scope+"${out_of_scope[@]}"})" \
	--argjson tripped "$(arr ${tripped+"${tripped[@]}"})" \
	--argjson behavior "$(arr ${behavior+"${behavior[@]}"})" \
	--argjson unverified "$(arr ${unverified+"${unverified[@]}"})" \
	'
  {
    since: $since,
    commits: $commits,
    files: ($touched | length),
    insertions: $insertions, deletions: $deletions,
    touched: $touched,
    outOfScope: $outOfScope,
    tripwirePaths: $tripped,
    behaviorBearing: $behavior,
    verification: $verification,
    divergedThreads: ($diverged | split(",") | map(select(length > 0)))
  }
  | . + {
      hardTriggers: (
        []
        + (if (.outOfScope | length) > 0
             then ["touched \(.outOfScope | length) file(s) outside the PR diff: \(.outOfScope | join(", "))"]
             else [] end)
        + (if .verification == "failed"
             then ["the repo verification command failed"]
             else [] end)
        + (if .verification == "none" and ($unverified | length) > 0
             then ["\($unverified | length) behaviour-bearing file(s) changed with nothing able to verify them: \($unverified | join(", "))"]
             else [] end)
        + (if (.tripwirePaths | length) > 0
             then ["touched documented tripwire path(s): \(.tripwirePaths | join(", "))"]
             else [] end)
        + (if (.divergedThreads | length) > 0
             then ["fix diverged from the reviewer suggestion on thread(s): \(.divergedThreads | join(", "))"]
             else [] end)
      )
    }
  | . + {
      sizeNotes: (
        []
        + (if .files > 8 then ["\(.files) files in one batch"] else [] end)
        + (if (.insertions + .deletions) > 200 then ["\(.insertions + .deletions) lines changed"] else [] end)
        + (if .commits > 5 then ["\(.commits) commits"] else [] end)
      )
    }
  | . + {
      level: (
        if (.hardTriggers | length) > 0 then "high"
        elif (.sizeNotes | length) > 0 or .verification == "none" then "elevated"
        else "low"
        end
      )
    }'
