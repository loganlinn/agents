---
name: kitty-remote-control
description: Inspect and control Kitty windows, tabs, layouts, commands, and agent CLIs through remote control. Use when the user asks to inspect or control Kitty. Requires kitty on PATH and execution from a Kitty terminal. Do not select merely because a task could benefit from a background terminal or another agent.
---

# Kitty remote control

Kitty organizes terminals as **OS windows → tabs → Kitty windows (terminal panes)**. Sessions can group project windows and describe startup layout; they are not detached terminal servers. Coding agents are ordinary programs inside windows: Kitty has no agent registry, readiness detector, or agent-turn lifecycle API.

For Herdr mappings, transport/setup details, version caveats, and advanced operations, read [the comparison report](references/herdr-comparison.md) as needed. Routine control does not require loading the whole report.

## Establish the connection

Require `kitty` on `PATH` and Kitty terminal context before issuing control commands:

```sh
command -v kitty
test -n "${KITTY_WINDOW_ID:-}"
kitty --version
kitty @ --help
kitty @ launch --help
kitty @ get-text --help
```

If either prerequisite check fails, explain that the skill must run from a Kitty terminal with `kitty` installed and on `PATH`, and stop terminal control. `KITTY_WINDOW_ID` is a context hint; validate it against the connected instance before acting. Documentation/help lookup itself does not require a live terminal connection.

A source checkout is not required. Use installed subcommand help as the authority for syntax. For documentation beyond help, read [documentation access](references/documentation.md): it explains optional browser-free local lookup through `kitty +runpy` and fetching source docs for the installed release.

These examples use `kitty @`, which dispatches to Kitty's remote-control client; a separate `kitten` command on `PATH` is not required. Bare `kitty` launches a terminal, bare `kitty @` opens an interactive control shell, and `launch` without a program creates a shell; none is a help probe.

Choose one connection and retain it for the task:

- Use the inherited `KITTY_LISTEN_ON` endpoint, otherwise the controlling terminal. Terminal context does not prove remote-control permission or connectivity.
- If the execution tool needs an explicit endpoint, use one supplied by the user or already established for this Kitty context. An endpoint does not waive the Kitty-terminal prerequisite. Do not scan for sockets or guess an instance from UI focus.
- An inherited `fd:NUMBER` endpoint works only while that descriptor is available; execution tools may drop descriptors or lack a controlling terminal. On failure, report the connection problem and obtain a usable endpoint.

Examples below use a Bash/Zsh command array. Include `--to` on **every** invocation when using an explicit endpoint:

```sh
rc=(kitty @)                       # inherited endpoint or controlling terminal
# Instead, for a supplied endpoint:
# rc=(kitty @ --to "$endpoint")
"${rc[@]}" ls
```

Use existing authorization. Password files or the configured password environment variable avoid putting secrets in command arguments. Do not print passwords, dump child environments, or silently enable remote control or rewrite configuration. Report connection/permission failures concretely; setup guidance is in the reference.

## Resolve exact targets

`ls` returns a JSON tree. Read window and parent tab IDs from that tree. Validate `KITTY_WINDOW_ID` against the connected instance, or use `ls --self` where caller context is available. Resolve any other requested target from the tree; ask if multiple plausible targets remain. Keep the endpoint with the IDs, and rediscover after instance restarts.

For example, inspect a previously resolved positive numeric window ID:

```sh
"${rc[@]}" ls --match "id:$target_id"
```

Inspect process command lines, cwd, and the screen before writing input. Titles and user variables are labels, not proof of a live agent's identity. Avoid showing unrelated environment data from `ls` in user-facing output.

For a single-window operation, verify exactly one window matches. Use `id:NUMBER`, not UI position, negative IDs, `recent`, or focused-state defaults. Match rules differ by command: **`launch --match` selects a tab**, while `--next-to` and `--source-window` select windows. Use `window_id:NUMBER` to select the tab containing a window. Tab `id:` matching can fall back to a window ID, so confirm the tab exists before tab operations.

## Launch sibling work

Default to the verified source tab, the task's working directory, its source session, and unchanged focus. Do not create a new tab, OS window, or Git worktree unless that topology is requested or needed for the task.

Resolve `source_id` before launching. Set `task_cwd` to the intended directory **on the Kitty host**. For local work, this is normally `$PWD`; for remote control, do not transmit a controller-local path assuming it exists on the host. Use `--cwd current` only when inheriting the source window's directory/SSH context is intended.

```sh
new_id=$("${rc[@]}" launch \
  --match "window_id:$source_id" \
  --next-to "id:$source_id" \
  --source-window "id:$source_id" \
  --cwd "$task_cwd" \
  --add-to-session . \
  --keep-focus \
  --title "$task_name" \
  --var "task=$task_name" \
  "$program" "${program_args[@]}")
```

Here `program` is the requested executable and `program_args` is an array of its verified arguments. No shell interprets these arguments; use an explicit shell only when shell syntax is needed. Check the launch exit status and returned ID, then inspect the created window. Launch returns a **plain window ID**, not a JSON result envelope. Keep a record of windows created by this task.

When the source tab uses `splits`, add `--location=split` for native automatic geometry, `--location=vsplit` for side-by-side, or `--location=hsplit` for stacked windows. These split locations apply only to `splits`. Preserve other layouts for ordinary sibling requests. If an exact requested split requires changing the tab layout, explain its effect and change it only within the user's authorized scope. `--next-to` alone does not select the correct tab.

`--keep-focus` preserves the current active window, which may differ from the source. `--add-to-session .` uses the specified source window's session and does not edit its session file. Feature-check these flags on older installations.

For ordinary commands, prefer direct launch over typing into an existing shell. Add `--hold` if output should remain available: Kitty starts a shell after the command exits. A supplied agent executable can be launched the same way, but successful launch does **not** establish readiness for a prompt.

## Read output and send input

```sh
"${rc[@]}" get-text --match "id:$target_id" --extent screen
"${rc[@]}" get-text --match "id:$target_id" --extent all
"${rc[@]}" get-text --match "id:$target_id" --extent last_cmd_output
```

Use `screen` for the current UI and `all` for available screen/history. Command-output extents require shell integration. Use `--ansi` only when styling is evidence. There is no `--lines` option; limit returned text locally if needed. Alternate-screen applications may discard output that scrollback cannot recover. Inspect installed `get-text --help` before using newer alternate-screen extents. Read a native transcript/artifact, or ask the agent to write its complete answer to a file, when terminal capture is insufficient.

Before prompting an existing agent, read the screen and verify the intended input surface is ready. Shell `at_prompt` does not describe an agent TUI. If it is at an approval/question dialog, handle that dialog only within existing user authorization; obtain the missing answer when necessary.

Prefer stdin or a file over positional text, which interprets backslash escapes. `prompt_file` must contain the exact intended text and be readable on the machine running `kitty`:

```sh
"${rc[@]}" send-text --match "id:$target_id" \
  --bracketed-paste=auto --from-file "$prompt_file"
# Allow the application to process the paste; inspect when uncertain.
"${rc[@]}" send-key --match "id:$target_id" enter
"${rc[@]}" get-text --match "id:$target_id" --extent screen
```

**`send-text` and `send-key` do not report remote delivery errors.** A zero exit status does not prove the target received input. These separate calls are not atomic. Look for evidence that the application accepted the prompt before retrying; never blindly duplicate a submission after a timeout or uncertain response.

Use logical keys such as `escape` or `ctrl+c` after checking `send-key --help`. Each is application input; interrupt only the intended work. For an existing shell, verify it is at its shell prompt before sending command text and Enter. Otherwise launch a new window.

## Wait and recover

Kitty has no equivalent of Herdr's agent-aware `prompt --wait`, `agent wait`, or `pane wait-output`. Compose bounded reads with a deadline appropriate to the task. If no deadline is supplied, use an initial 120-second observation window, with short waits between reads; on expiry report the observed state and leave the work running. Continue longer monitoring when requested. Compare against a pre-submission snapshot so old output cannot masquerade as fresh completion.

Use explicit task completion text, a native result artifact, or a task-specific condition. Silence, unchanged output, an existing process, attention flags, and user variables do not prove completion. Inspect a blocked or ambiguous screen before deciding on input.

For a finite program, installed `launch --wait-for-child-to-exit --response-timeout 120` waits for process exit and prints its exit code or signal **instead of a window ID**. Interpret that returned value separately from the remote-control command's exit status. It cannot detect a turn ending in an interactive agent. On timeout, inspect the launched work before repeating the launch. `kitty @ run` is a separate host process execution facility, not execution in an existing interactive window.

## Manage and clean up

Use exact, inspected IDs and relevant subcommand help:

| Intent | Native operation |
|---|---|
| Close an owned/requested terminal | `close-window --match "id:$target_id"` |
| Focus a terminal or tab | `focus-window --match "id:$target_id"`; `focus-tab --match "id:$tab_id"` |
| Move a terminal to a verified tab | `detach-window --match "id:$target_id" --target-tab "id:$tab_id" --stay-in-tab` |
| Rename a terminal or tab | `set-window-title --match "id:$target_id" TITLE`; `set-tab-title --match "id:$tab_id" TITLE` |
| Resize a terminal | `resize-window --match "id:$target_id" --axis horizontal --increment 2` |
| Select an enabled layout | `goto-layout --match "id:$tab_id" LAYOUT` |

Prefix each operation with the established `"${rc[@]}"`. Layouts constrain resizing. Re-read topology after moves or closes. Close only windows/tabs created for the task or explicitly requested by the user; closing can terminate running processes. Leave useful ongoing work intact when reporting completion.

Kitty's `detach-window` moves a live window; it does not detach a persistent client. Saved sessions recreate layout/programs, not running process memory or arbitrary agent conversations. Agent resume uses the agent's own CLI/session mechanism. Do not stop the user's Kitty process or broaden remote-control permissions as a workaround.
