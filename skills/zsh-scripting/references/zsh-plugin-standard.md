# Zsh Plugin Standard

Specification for writing Zsh plugins that load cleanly under any compliant plugin manager (zinit, antidote, zgenom, zplug, oh-my-zsh, prezto, znap). Source: <https://wiki.zshell.dev/community/zsh_plugin_standard>.

A Zsh plugin is a directory containing a main `.plugin.zsh` script, optionally with `functions/` (autoload functions + completions), `bin/` (executables), Makefiles, and docs. The main script is sourced; everything else is loaded on demand.

## 1. Standardized `$0` handling

`$0` is unreliable inside a sourced file — it may be `zsh`, the manager's loader, or the plugin file itself depending on how it was invoked. Use this idiom at the top of the main plugin file to normalize:

```zsh
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"
```

After these two lines, `$0` is the absolute path of the plugin script regardless of how it was loaded (including `eval "$(<plugin.zsh)"`). Subsequent code can use `${0:h}` for the plugin directory.

Compliant plugin managers set `$ZERO` themselves before sourcing, so the plugin doesn't even need to compute `$0` — but the fallback chain handles non-compliant managers too.

## 2. Directory layout

```
plugin-name/
├── plugin-name.plugin.zsh    # main script, sourced
├── functions/                 # autoloadable functions + completions
│   ├── my-helper
│   └── _my-completion
├── bin/                       # executables
│   └── plugin-tool
├── Makefile                   # optional, for build steps
└── README.md
```

### `functions/` directory

A compliant manager adds this to `$fpath` automatically (signaled by `f` in `$PMSPEC`). If absent, the plugin must add it itself:

```zsh
if [[ $PMSPEC != *f* ]]; then
  fpath+=( "${0:h}/functions" )
fi
```

Files inside `functions/` are autoloaded on first call. Filename = function name. Completions start with `_`.

### `bin/` directory

Holds executables. Compliant managers (signaled by `b` in `$PMSPEC`) add `bin/` to `$PATH` or create shims. Non-compliant: the plugin script must do it:

```zsh
if [[ $PMSPEC != *b* ]]; then
  path+=( "${0:h}/bin" )
fi
```

## 3. Function naming prefixes

Use sigil prefixes to organize functions and avoid namespace pollution:

| Prefix | Meaning | Example |
|--------|---------|---------|
| `.`    | Private (internal) function | `.prompt_zinc_get_value` |
| `→`    | Hook function (preexec, precmd, chpwd, etc.) | `→prompt_zinc_precmd` |
| `+`    | Output-producing function | `+prompt_zinc_output_segment` |
| `/`    | Debugging/instrumentation function | `/prompt_zinc_dmsg` |
| `@`    | Public API function (intended for end users / other plugins) | `@zsh-plugin-run-on-update` |

These prefixes are valid Zsh identifiers and are stable across plugin managers.

## 4. Unload function

Define `{pluginname}_plugin_unload` to clean up when the plugin is unloaded. Compliant managers (signaled by `u` in `$PMSPEC`) call this function on unload:

```zsh
my-plugin_plugin_unload() {
  # Remove hooks
  add-zsh-hook -d precmd →my-plugin_precmd
  # Unset functions / aliases / variables
  unset MY_PLUGIN_VAR
  unalias mp 2>/dev/null
  # Remove the unload function itself
  unfunction $0
}
```

The unload function should reverse everything the plugin did on load: hooks added, ZLE widgets bound, fpath/path entries, exports, aliases.

## 5. `@zsh-plugin-run-on-unload`

For ad-hoc cleanup code without defining a full unload function, register snippets:

```zsh
@zsh-plugin-run-on-unload 'add-zsh-hook -d precmd my_precmd' \
                          'unset MY_VAR' \
                          '/path/to/cleanup-helper'
```

Manager evaluates each snippet (via `eval`) in the plugin's directory when unloading. Available when `U` is in `$PMSPEC`.

## 6. `@zsh-plugin-run-on-update`

Register code to run after the plugin's repository is pulled:

```zsh
@zsh-plugin-run-on-update 'make rebuild' './post-update.sh'
```

Available when `p` is in `$PMSPEC`. Useful for compiling native modules, regenerating caches, running migrations.

## 7. Plugin manager indicators

### `$zsh_loaded_plugins`

Array of all currently loaded plugin identifiers (e.g. `user/plugin-name`). Plugins can inspect it to detect dependencies:

```zsh
if (( ! ${zsh_loaded_plugins[(I)*/dependency-plugin]} )); then
  print -u2 "my-plugin: requires dependency-plugin to be loaded first"
  return 1
fi
```

Available when `i` is in `$PMSPEC`.

### `$PMSPEC`

A capability string. Each letter indicates a supported feature:

| Letter | Meaning |
|--------|---------|
| `0`    | Sets `$ZERO` before sourcing |
| `f`    | Adds `functions/` to `$fpath` |
| `b`    | Adds `bin/` to `$PATH` |
| `u`    | Calls `{name}_plugin_unload` |
| `U`    | Honors `@zsh-plugin-run-on-unload` |
| `p`    | Honors `@zsh-plugin-run-on-update` |
| `i`    | Populates `$zsh_loaded_plugins` |
| `P`    | Provides `$ZPFX` |
| `s`    | Exports `$PMSPEC` itself |

A fully compliant manager exports `PMSPEC=0fuUpiPs` (or similar). Plugins test capabilities with `[[ $PMSPEC == *X* ]]`.

### `$ZPFX`

Path to a dedicated directory for plugin-installed software (binaries, libraries, headers). Standard pattern:

```zsh
make PREFIX="$ZPFX" install
```

Lets plugins ship build-from-source dependencies without colliding with system paths. Available when `P` is in `$PMSPEC`.

## 8. Standard options for the main function

Inside any function that does non-trivial work, restore Zsh's well-defined defaults so caller's `setopt`s don't interfere:

```zsh
my-plugin-main() {
  builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global typeset_silent \
    no_short_loops rc_quotes no_auto_pushd

  local MATCH REPLY; integer MBEGIN MEND
  local -a match mbegin mend reply

  # ... function body ...
}
```

The `${=${options[xtrace]:#off}:+-o xtrace}` idiom propagates `xtrace` (`set -x`) if the caller had it enabled — useful for debugging.

Always localize the regex/match variables (`MATCH`, `MBEGIN`, `MEND`, `match`, `mbegin`, `mend`, `REPLY`, `reply`) so nested pattern matching doesn't clobber the caller's state.

## 9. Scope pollution traps

A plugin that defines helper functions at top level pollutes the global namespace. To confine helpers to load-time only:

```zsh
# Record current functions
typeset -gA __my_plugin_fn_snapshot
__my_plugin_fn_snapshot=( ${(k)functions} )

# Arrange cleanup on script exit
trap 'unset -f -- "${(k)functions[@]:|__my_plugin_fn_snapshot}"; unset __my_plugin_fn_snapshot' EXIT

# ... define helpers, run them ...
.helper1() { ... }
.helper2() { ... }
.helper1
.helper2
```

The `:|` array operator subtracts one array from another — leaving only newly-defined function names, which the trap unsets. The plugin's *public* functions should be defined separately (after the snapshot) and kept.

For parameters, consolidate into a single associative array per plugin:

```zsh
typeset -gA Plugins
Plugins[MY_PLUGIN_DIR]="${0:h}"
Plugins[MY_PLUGIN_CACHE]="${0:h}/.cache"
```

This puts all of a plugin's state under one key, easy to inspect (`print -r -- ${(kv)Plugins}`) and easy to clean up (`unset Plugins[MY_PLUGIN_*]`).

## 10. Hook installation

Never overwrite `precmd()` / `preexec()` / `chpwd()` directly — that clobbers other plugins' hooks. Use the standard helper:

```zsh
autoload -Uz add-zsh-hook
add-zsh-hook precmd  →my-plugin_precmd
add-zsh-hook preexec →my-plugin_preexec
add-zsh-hook chpwd   →my-plugin_chpwd
```

Multiple hooks per event are chained automatically. Remove with `add-zsh-hook -d <event> <fn>`.

For ZLE (line editor) hooks:

```zsh
autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-init    →my-plugin_line_init
add-zle-hook-widget line-pre-redraw →my-plugin_pre_redraw
add-zle-hook-widget zle-keymap-select →my-plugin_keymap_select
```

## 11. Recommended skeleton

A minimal compliant plugin:

```zsh
# my-plugin.plugin.zsh

# 1. Normalize $0 → absolute path of this file
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

# 2. Add fpath/path entries if the manager hasn't
if [[ $PMSPEC != *f* ]]; then
  fpath+=( "${0:h}/functions" )
fi
if [[ $PMSPEC != *b* ]]; then
  path+=( "${0:h}/bin" )
fi

# 3. State container
typeset -gA Plugins
Plugins[MY_PLUGIN_DIR]="${0:h}"

# 4. Public functions (kept after load)
@my-plugin-public-api() {
  emulate -L zsh
  setopt extended_glob
  # ...
}

# 5. Hook installation
autoload -Uz add-zsh-hook
→my-plugin_precmd() {
  # ...
}
add-zsh-hook precmd →my-plugin_precmd

# 6. Unload function
my-plugin_plugin_unload() {
  add-zsh-hook -d precmd →my-plugin_precmd
  unfunction →my-plugin_precmd @my-plugin-public-api
  unset 'Plugins[MY_PLUGIN_DIR]'
  unfunction $0
}

# 7. Update hook
@zsh-plugin-run-on-update 'make -C "${0:h}" rebuild'
```

## 12. Distribution checklist

- Repo name matches plugin name (`zsh-foo` or `user/foo`).
- Main file is `<name>.plugin.zsh` at repo root.
- Includes a `README.md` with: install snippets for the major managers (zinit, antidote, oh-my-zsh manual), required Zsh version, dependencies.
- Tags semantic versions (`v1.0.0`) for managers that pin.
- `LICENSE` file at root.
- No bash-isms: test with `zsh -f -c 'source ./my-plugin.plugin.zsh'`.
- Provide an `init.zsh` symlink to `<name>.plugin.zsh` for prezto compatibility (optional but appreciated).

## Reference

- Spec: <https://wiki.zshell.dev/community/zsh_plugin_standard>
- Handbook (general scripting): <https://wiki.zshell.dev/community/zsh_handbook>
- ZSH source: `~/src/github.com/zsh-users/zsh/` (if cloned)
- Example compliant plugins: zinit's own modules, romkatv/powerlevel10k, zsh-users/zsh-autosuggestions.
