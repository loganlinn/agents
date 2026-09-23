#!/bin/bash
# Validates all skill directories changed in a pull request or push.
#
# Adapted from:
# https://github.com/agent-ecosystem/skill-validator/tree/main/examples/ci/.github
#
# Usage: validate-skills.sh <diff-base> [skills-dir]
#   diff-base   Committish to diff against (e.g. "origin/main" or a SHA).
#               When omitted or unresolvable, all skills are validated.
#   skills-dir  The directory containing skill subdirectories (default: "skills").
#
# Exit codes:
#   0  All validated skills passed.
#   1  One or more skills failed validation.

# -e is intentionally omitted: all error paths are handled explicitly,
# so abort-on-error would conflict with the || FAILED=1 accumulator pattern.
set -uo pipefail

DIFF_BASE="${1:-}"
SKILLS_DIR="${2:-skills}"

# Strip trailing slash for consistent path handling.
SKILLS_DIR="${SKILLS_DIR%/}"

# Find unique skill directories containing files changed since the diff base.
# The three-dot diff requires fetch-depth: 0, which is always the case on
# GitHub Actions but may not be in local runs.
changed_skills=()
if [ -n "$DIFF_BASE" ]; then
	mapfile -t changed_skills < <(git diff --name-only "${DIFF_BASE}...HEAD" -- "$SKILLS_DIR/" \
		2>/dev/null |
		sed "s|^${SKILLS_DIR}/||" |
		cut -d'/' -f1 |
		sort -u |
		grep -v '^$')
fi

if [ "${#changed_skills[@]}" -eq 0 ]; then
	# Fallback: validate all skill directories (e.g. when the diff base is
	# unresolvable, or when a change only deletes files with no remaining dirs).
	echo "Could not determine changed skills from git diff; validating all skills."
	mapfile -t changed_skills < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -u)
fi

if [ "${#changed_skills[@]}" -eq 0 ]; then
	echo "No skill directories found in ${SKILLS_DIR}/, skipping validation."
	exit 0
fi

FAILED=0
for skill in "${changed_skills[@]}"; do
	# Skip skills whose directories were deleted in this change.
	if [ ! -d "${SKILLS_DIR}/$skill" ]; then
		echo "Skipping deleted skill: $skill"
		continue
	fi

	# Run validation with markdown output so the result is written to the job
	# summary in one pass. --emit-annotations works with any output format, so
	# inline PR annotations are still emitted alongside the markdown report.
	# We use process substitution to:
	# 1. Send all output (including ::error commands) to stdout for GitHub Actions
	# 2. Filter out ::error/::warning/::notice lines before writing to the summary
	skill-validator check --strict --allow-dirs=agents --emit-annotations -o markdown "${SKILLS_DIR}/$skill/" |
		tee >(grep -v '^::' >>"${GITHUB_STEP_SUMMARY:-/dev/null}") || FAILED=1
done

if [ $FAILED -ne 0 ]; then
	echo ""
	echo "Skill validation failed!"
	echo ""
	echo "See the Job Summary for detailed validation results:"
	echo "  https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
	echo ""
fi

exit $FAILED
