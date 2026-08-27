---
name: zsh-scripting
description: |
  This skill should be used when the user asks to "write a zsh script", "convert bash to zsh", "use zsh idioms", "zsh parameter expansion", "zsh glob qualifiers", "zsh arrays", "zsh extended_glob", "zsh hooks (chpwd, precmd, preexec)", or works with `.zshrc`, `.zshenv`, ZLE widgets, completion scripts (`_*` files), or any `.zsh` file. Provides native Zsh expertise: parameter expansion flags, glob qualifiers, array operations, and idiomatic patterns that replace external utilities (grep/sed/awk/cut) with builtin syntax. For zsh plugin authoring (the Zsh Plugin Standard, $0 handling, PMSPEC, function naming, unload hooks), consult `references/zsh-plugin-standard.md`.
---

# Zsh Scripting Expert

Write idiomatic Zsh — not portable POSIX, not bash-with-zsh-shebang. Lean on parameter expansion flags, glob qualifiers, and builtin features to eliminate forks to `grep`, `sed`, `awk`, `cut`, `tr`, `dirname`, `basename`, `wc`, `head`, `tail`, `cat`.

When working with files named `.zshrc`, `.zshenv`, `.zprofile`, `.zlogin`, `.zlogout`, anything under `functions/`, completion files starting with `_`, or any `.zsh` extension, prefer the Zsh-native form below.

## Core principles

1. **Quote properly, but use Zsh's word-splitting model.** Unquoted `$var` does NOT split in Zsh (unlike bash). Use `${=var}` to force splitting, `${(z)var}` to split as the parser would.
2. **Arrays are first-class.** Use `"${array[@]}"` (preserves empty elements, KSH_ARRAYS-compatible) or `"${(@)array}"`. Index from 1, not 0.
3. **Parameter expansion flags replace pipelines.** `(f)` splits on newlines, `(s:X:)` splits on `X`, `(j:X:)` joins, `(u)` uniques, `(o)`/`(O)` sort, `(M)` keeps matches, `(q)` quotes, `(Q)` dequotes, `(L)`/`(U)` lowercase/uppercase, `(P)` indirects, `(k)`/`(v)` hash keys/values.
4. **Modifiers replace path utils.** `:h` (head/dirname), `:t` (tail/basename), `:r` (root, no ext), `:e` (extension), `:A` (resolve absolute), `:a` (absolute, no symlink resolve), `:l`/`:u` (case), `:Q` (dequote).
5. **Enable extended_glob** at the top of any non-trivial script: `setopt extended_glob`. Many idioms below require it (`~`, `^`, `#b`, `#m`, `(#i)`, `(#s)`, `(#e)`).

## Script preamble (recommended)

```zsh
#!/usr/bin/env zsh
emulate -L zsh
setopt extended_glob warn_create_global typeset_silent \
       no_short_loops rc_quotes no_auto_pushd pipefail err_return
local MATCH REPLY; integer MBEGIN MEND
local -a match mbegin mend reply
```

`emulate -L zsh` localizes options, insulating the script from the user's interactive config. `warn_create_global` catches missing `local`. `err_return` is Zsh's analogue of `set -e` for functions.

## Parameter expansion cheatsheet

```zsh
# Path manipulation (no dirname/basename/realpath fork)
"${PWD:h}"          # dirname
"${PWD:t}"          # basename
"${file:r}"         # strip extension
"${file:e}"         # extension only
"${file:A}"         # absolute, resolved symlinks
"${HOME}/${file:t:r}.bak"

# Read whole file into array of lines (preserves empties)
local -a lines
lines=( "${(@f)"$(<path/to/file)"}" )

# Read command output into array
lines=( "${(@f)"$(some-command)"}" )

# Default / alternate (ternary)
"${var:-fallback}"          # var or fallback
"${var:+set}"               # 'set' if var non-empty, else empty
"${${var:+yes}:-no}"        # full ternary

# Lowercase / uppercase
"${(L)var}"  "${(U)var}"

# Trim / replace
"${var## *}"                # strip leading whitespace
"${var%% *}"                # strip trailing whitespace
"${var//foo/bar}"           # replace all
"${var/#prefix/}"           # strip prefix
"${var/%suffix/}"           # strip suffix

# Length
"${#var}"                   # string length
"${#array}"                 # array length (1-based count)
```

## Arrays and associative arrays

```zsh
local -a list=( foo bar baz )
local -A map=( key1 val1 key2 val2 )    # or: map[key1]=val1

# Filter (grep-equivalent)
local -a matches=( "${(M)list:#*ar*}" )    # keep elements matching *ar*
local -a rest=(    "${list:#*ar*}" )       # drop elements matching *ar*

# Case-insensitive
"${(M)list:#(#i)*foo*}"

# Unique
typeset -aU uniq=( "${list[@]}" )          # declare unique array
local -a u=( "${(u)list[@]}" )             # one-shot uniqueness

# Sort
"${(o)list[@]}"     # ascending
"${(On)list[@]}"    # descending, numeric

# Join / split
local joined="${(j:,:)list}"               # foo,bar,baz
local -a split=( "${(s:,:)joined}" )

# Iterate hash
for k v in "${(@kv)map}"; do print -r -- "$k=$v"; done

# Indirect (read var whose name is in another var)
local name=PATH
print -r -- "${(P)name}"
```

## Glob qualifiers (no `find` fork)

Append `(...)` to a glob pattern:

```zsh
*(.)            # regular files only
*(/)            # directories only
*(@)            # symlinks
*(*)            # executables
*(.x)           # files with executable bit (any)
*(.L+10k)       # files >10K
*(.mh-1)        # modified within last hour
*(.om[1,5])     # 5 newest files
*(N)            # NULL_GLOB: empty array if no match (don't error)
**/*.zsh(.N)    # recursive, regular files, may be empty
*(u0)           # owned by uid 0
*(:A)           # apply :A modifier to each match
```

## Conditionals and pattern matching

```zsh
# Glob patterns in [[ ... ]] (no quoting on RHS)
[[ $file == *.zsh ]]
[[ $name == (foo|bar) ]]
[[ $line == [[:space:]]# ]]      # all-whitespace; # means "zero or more"

# Negation (extended_glob)
[[ $x == ^*.tmp ]]               # NOT *.tmp
[[ $x == *(#c2,4) ]]             # 2 to 4 occurrences

# Regex with backreferences
if [[ $str == (#b)([a-z]##)-([0-9]##) ]]; then
  print -r -- "name=$match[1] num=$match[2]"
fi

# Numeric
(( a > b ))                       # arithmetic context
(( count++ ))
```

## I/O and process substitution

```zsh
# Read file → string (no `cat`)
local content="$(<file.txt)"

# Read line by line (preserves backslashes with -r)
while IFS= read -r line; do
  print -r -- "$line"
done <file.txt

# Process substitution
diff =(cmd1) =(cmd2)              # temp files
cmd <(producer)                   # named pipe input
```

## Functions and scope

```zsh
my_fn() {
  emulate -L zsh
  setopt extended_glob
  local arg1=$1 arg2=$2
  local -a items
  integer count=0
  # ... body ...
  print -r -- "$result"           # return data via stdout
  return 0
}
```

- `local` / `typeset` confine variables to the function. Without it, Zsh dynamic-scopes (caller sees changes).
- Use `print -r -- "$x"` instead of `echo "$x"` — `echo` mangles backslashes and dash-prefixed args.
- Use `print -r -- "msg" >&2` for stderr (prefer `>&2` at end per project shell rules).

## Hooks (interactive Zsh)

```zsh
autoload -Uz add-zsh-hook
add-zsh-hook precmd  my_precmd_fn       # before each prompt
add-zsh-hook preexec my_preexec_fn      # before each command runs
add-zsh-hook chpwd   my_chpwd_fn        # after cd
add-zsh-hook periodic my_periodic_fn    # every $PERIOD seconds

# ZLE (line editor) hooks
autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-init my_line_init_widget
```

Never overwrite `precmd()` / `preexec()` directly — that clobbers other plugins. Always use `add-zsh-hook`.

## Performance idioms

- One fork beats many. `${${(f)$(cmd)}[3]}` is one fork; `cmd | head -3 | tail -1` is three.
- Built-ins beat externals: `print` over `echo`, `[[ ]]` over `[ ]`, `(( ))` over `expr`, `${var:h}` over `dirname "$var"`.
- For large loops, prefer parameter expansion over per-iteration externals.
- Profile with `zmodload zsh/zprof; zprof` (load at top, dump at bottom).

## Common gotchas

- **Indexing starts at 1.** `$array[1]` is the first element. `$array[0]` is empty (or the function name in some contexts).
- **Negative indices count from end:** `$array[-1]` is last.
- **`$var` does NOT word-split** unquoted (unless `SH_WORD_SPLIT` set). Use `${=var}` to split.
- **`*` in `[[ $x == * ]]` is a glob, not a regex.** Use `=~` for regex.
- **Empty array elements are preserved** with `"${(@)array}"` and `"${array[@]}"`, lost with `${array[*]}` or `"${array[*]}"`.
- **`setopt` is global** unless `emulate -L zsh` localizes it.
- **`local` inside conditionals** still hoists the declaration; assign in the same statement.

## Completion scripts

Files named `_command` placed on `$fpath` provide completion. Minimal skeleton:

```zsh
#compdef mycommand

_mycommand() {
  local -a subcmds
  subcmds=(
    'build:Compile the project'
    'test:Run tests'
    'deploy:Push to production'
  )
  _describe 'subcommand' subcmds
}

_mycommand "$@"
```

Use `_arguments`, `_describe`, `_values`, `_files`, `_path_files -/` for directories. Read existing completions under `$(brew --prefix)/share/zsh/site-functions/` or `/usr/share/zsh/*/functions/Completion/` for examples.

## Linting and formatting

- No `shellcheck` support for true Zsh syntax. For Zsh-specific files, lint manually or use `zsh -n script.zsh` (parse-only).
- For mixed-shell scripts, run `shellcheck --shell=bash` on portable subsets only.
- Format with consistent 2-space indent, `; do` / `; then` on same line as `for` / `while` / `if`.

## When NOT to use Zsh

- Scripts that must run on systems without Zsh installed (Alpine containers, minimal CI runners, BSD bootstrap). Prefer POSIX `sh` or bundle a Zsh binary.
- Scripts checked into projects whose contributors don't know Zsh — readability matters more than terseness.
- System init / package install scripts — stick to `/bin/sh`.

## Authoring Zsh plugins

For plugin development specifically (the Zsh Plugin Standard, `$0` handling, `PMSPEC`, function naming with `.`/`->`/`+`/`/`/`@` prefixes, `_plugin_unload` functions, `@zsh-plugin-run-on-unload`, `ZPFX`, scope-pollution traps, plugin manager interop), consult:

**`references/zsh-plugin-standard.md`**

That file covers the conventions a plugin author must follow to be loadable by any compliant plugin manager (zinit, antidote, zgenom, zplug, oh-my-zsh, etc.).

## Reference

- Official manual: `man zshall` (single-page everything), `man zshexpn` (parameter expansion), `man zshparam`, `man zshmisc`.
- Local clone (if present): `~/src/github.com/zsh-users/zsh/Doc/`.
- ZSH Plugin Standard wiki: <https://wiki.zshell.dev/community/zsh_plugin_standard>.
- ZSH Handbook wiki: <https://wiki.zshell.dev/community/zsh_handbook>.
