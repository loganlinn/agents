#!/usr/bin/env bash
# Classify which verification command applies to each changed path. Read-only:
# it decides WHAT to run and never runs it, because the checks are slow and
# side-effecting and belong to the agent.
#
# Its real job is to make the "unverified" list mechanical. Left to self-report,
# an agent can quietly decide its change did not need checking — which is the
# rationalization the risk gate exists to prevent.
#
# Usage: verify.sh --paths '<json array of repo-relative paths>' [--repo-root <dir>]
set -euo pipefail

paths='[]' root=''

while [[ $# -gt 0 ]]; do
	case "$1" in
	--paths) paths="$2" && shift 2 ;;
	--repo-root) root="$2" && shift 2 ;;
	*) echo >&2 "verify.sh: unknown argument: $1" && exit 2 ;;
	esac
done

[[ -n "$root" ]] || root=$(git rev-parse --show-toplevel 2>/dev/null || echo .)

# A Terraform directory is a plannable root only if it declares a backend.
# Module directories do not, which is why `terraform plan` can never verify
# them and `init -backend=false && validate` is the correct check.
tf_is_root() {
	local dir="$1"
	# The directory may not exist locally — the path can come from a PR whose
	# branch is not checked out. Probe the backend when we can see the files,
	# and fall back to the layout convention when we cannot.
	if [[ -d "$root/$dir" ]] && compgen -G "$root/$dir/*.tf" >/dev/null; then
		# Not anchored to line start: a backend block may be inlined rather than
		# fmt-ed onto its own line.
		grep -rqE '(^|[[:space:]{])backend[[:space:]]+"' "$root/$dir" --include='*.tf' 2>/dev/null
		return
	fi
	case "$dir" in
	*/modules/* | modules/*) return 1 ;;
	*) return 0 ;;
	esac
}

# Nearest ancestor directory that contains a package.json file.
js_package_dir() {
	local dir="$1"
	while [[ -n "$dir" ]]; do
		[[ -f "$root/$dir/package.json" ]] && printf '%s' "$dir" && return 0
		[[ "$dir" == "." ]] && break
		dir=$(dirname "$dir")
	done
	return 1
}

js_package_manager() {
	local dir="$1" manager manifest
	while [[ -n "$dir" ]]; do
		manifest="$root/$dir/package.json"
		if [[ -f "$manifest" ]]; then
			manager=$(jq -r '.packageManager // empty | split("@")[0]' "$manifest")
			case "$manager" in
			bun | npm | pnpm | yarn)
				printf '%s' "$manager"
				return
				;;
			esac
		fi

		[[ -f "$root/$dir/bun.lock" || -f "$root/$dir/bun.lockb" ]] && printf 'bun' && return
		[[ -f "$root/$dir/pnpm-lock.yaml" ]] && printf 'pnpm' && return
		[[ -f "$root/$dir/yarn.lock" ]] && printf 'yarn' && return
		[[ -f "$root/$dir/package-lock.json" ]] && printf 'npm' && return
		[[ "$dir" == "." ]] && break
		dir=$(dirname "$dir")
	done
	printf 'npm'
}

js_check_command() {
	local pkg="$1" manager script command='' separator=''
	local manifest="$root/$pkg/package.json"
	manager=$(js_package_manager "$pkg")

	for script in check typecheck lint test; do
		jq -e --arg script "$script" '.scripts[$script] | type == "string"' "$manifest" >/dev/null ||
			continue
		command+="${separator}${manager} run ${script}"
		separator=' && '
	done

	[[ -n "$command" ]] || return 1
	printf '(cd %s && %s)' "$pkg" "$command"
}

classify() {
	local p="$1" dir pkg cmd
	dir=$(dirname "$p")

	case "$p" in
	*.md | *.mdx | *.txt | docs/* | */docs/* | LICENSE*)
		printf 'docs\t-\tfalse\ttrue\n'
		return
		;;
	*.sh)
		printf 'shell\tshellcheck %s && shfmt -d %s\ttrue\ttrue\n' "$p" "$p"
		return
		;;
	*.sh.tftpl | *.bash.tftpl)
		printf 'shell-template\tsed -E "s/\\$\\{[^}]*\\}/PLACEHOLDER/g" %s | shellcheck --shell=bash -\ttrue\ttrue\n' "$p"
		return
		;;
	*.tf | *.tfvars)
		if tf_is_root "$dir"; then
			printf 'terraform-root\t(cd %s && terraform fmt -check && terraform plan)\ttrue\ttrue\n' "$dir"
		else
			printf 'terraform-module\t(cd %s && terraform fmt -check && terraform init -backend=false && terraform validate && tflint)\ttrue\ttrue\n' "$dir"
		fi
		return
		;;
	*.tftpl)
		printf 'template\t-\ttrue\tfalse\n'
		return
		;;
	esac

	case "$p" in
	*.ts | *.tsx | *.js | *.jsx | *.mjs | *.cjs)
		if pkg=$(js_package_dir "$dir"); then
			if cmd=$(js_check_command "$pkg"); then
				printf 'js-package\t%s\ttrue\ttrue\n' "$cmd"
			else
				printf 'js-package\t-\ttrue\tfalse\n'
			fi
		else
			printf 'js-loose\t-\ttrue\tfalse\n'
		fi
		return
		;;
	esac

	printf 'other\t-\ttrue\tfalse\n'
}

rows='[]'
while read -r p; do
	[[ -z "$p" ]] && continue
	IFS=$'\t' read -r kind cmd behavior verifiable < <(classify "$p")
	rows=$(jq --arg p "$p" --arg k "$kind" --arg c "$cmd" \
		--argjson b "${behavior:-true}" --argjson v "${verifiable:-false}" \
		'. + [{path:$p, kind:$k, command:(if $c=="-" or $c=="" then null else $c end), behaviorBearing:$b, verifiable:$v}]' <<<"$rows")
done < <(jq -r '.[]' <<<"$paths")

jq -n --argjson rows "$rows" '
  {
    paths: $rows,
    # Distinct commands to run, so a batch touching six files in one module
    # runs one validate rather than six.
    commands: ([$rows[] | select(.command != null) | .command] | unique),
    # Behaviour-bearing and nothing can check it. Feeds risk.sh --unverified.
    unverified: [$rows[] | select(.behaviorBearing and (.verifiable | not)) | .path]
  }'
