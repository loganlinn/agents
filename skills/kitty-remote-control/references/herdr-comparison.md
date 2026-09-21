# Herdr v0.9.0 and Kitty remote control

Research reference for the Kitty skill. Use it when translating a Herdr workflow, investigating connection/setup behavior, or checking capabilities that have no exact native equivalent.

## Sources and verification boundary

Herdr sources are pinned to **v0.9.0**:

- [Agent guide](https://github.com/herdrdev/herdr/blob/v0.9.0/distribution/agent-guide.md)
- [CLI reference](https://github.com/herdrdev/herdr/blob/v0.9.0/docs/next/website/src/content/docs/cli-reference.mdx)
- [Concepts](https://github.com/herdrdev/herdr/blob/v0.9.0/docs/next/website/src/content/docs/concepts.mdx)
- [Session state and restore](https://github.com/herdrdev/herdr/blob/v0.9.0/docs/next/website/src/content/docs/session-state.mdx)
- [Skill](https://github.com/herdrdev/herdr/blob/v0.9.0/skills/herdr/SKILL.md)
- [Socket API](https://github.com/herdrdev/herdr/blob/v0.9.0/docs/next/website/src/content/docs/socket-api.mdx)

The `docs/next` paths are contents of the release tag, not moving development documentation. The local installed Herdr skill differs from the requested tagged skill, including machine scoping and completion-seen semantics; the tagged version is the research baseline.

The original research used Kitty documentation and source at commit **`2d6d47a3f830e761ae8a75246701d7e63b95d510`**, version **0.48.2**. Installed CLI help reports **0.47.4**. Installed help takes precedence for available command syntax; optional fields and flags must be checked at runtime. In particular, installed `get-text` lacks the checkout's `alternate` and `alternate_scrollback` extents.

Pinned Kitty sources used throughout this report:

- [Glossary](https://github.com/kovidgoyal/kitty/blob/2d6d47a3f830e761ae8a75246701d7e63b95d510/docs/glossary.rst)
- [Launch documentation](https://github.com/kovidgoyal/kitty/blob/2d6d47a3f830e761ae8a75246701d7e63b95d510/docs/launch.rst) and [implementation](https://github.com/kovidgoyal/kitty/blob/2d6d47a3f830e761ae8a75246701d7e63b95d510/kitty/launch.py)
- [Layouts](https://github.com/kovidgoyal/kitty/blob/2d6d47a3f830e761ae8a75246701d7e63b95d510/docs/layouts.rst)
- [Options definitions](https://github.com/kovidgoyal/kitty/blob/2d6d47a3f830e761ae8a75246701d7e63b95d510/kitty/options/definition.py)
- [Remote commands](https://github.com/kovidgoyal/kitty/tree/2d6d47a3f830e761ae8a75246701d7e63b95d510/kitty/rc)
- [Remote-control documentation](https://github.com/kovidgoyal/kitty/blob/2d6d47a3f830e761ae8a75246701d7e63b95d510/docs/remote-control.rst) and [transport implementation](https://github.com/kovidgoyal/kitty/blob/2d6d47a3f830e761ae8a75246701d7e63b95d510/kitty/remote_control.py)
- [Sessions](https://github.com/kovidgoyal/kitty/blob/2d6d47a3f830e761ae8a75246701d7e63b95d510/docs/sessions.rst)
- [Window state and text extraction](https://github.com/kovidgoyal/kitty/blob/2d6d47a3f830e761ae8a75246701d7e63b95d510/kitty/window.py)

Source paths below are relative to the linked Kitty source revision; they do not require a local checkout. For installed documentation lookup and release-matched web sources, see [documentation access](documentation.md). The examples are grounded in source and installed help; validation of a representative subset is recorded at the end. They do not imply that every GUI, agent, or remote-host scenario has been exercised.

## Concepts and hierarchy

| Herdr | Kitty counterpart | Difference |
|---|---|---|
| Session | Kitty process/control endpoint; separately, Kitty session files | Herdr sessions are server namespaces. Kitty session files describe startup and support grouping live project windows. |
| Workspace | A project session, optionally an OS window | No distinct Herdr-style workspace object or workspace CLI. |
| Tab | Tab | Kitty tabs belong to OS windows. |
| Pane | Kitty window | A terminal pane is distinct from an OS window. |
| Pane layout | Tab layout | Arbitrary binary splitting belongs to the `splits` layout. |
| Agent | Program in a window | No coding-agent registry, kind validation, readiness detector, or lifecycle state machine. |
| Agent name | Title/user variable, used as a label | Labels are not validated identities and need not disappear when a program exits. |
| Terminal ID | Window ID plus child PID | Container, process, and native agent session IDs are separate concepts. |
| Detached client | No direct equivalent | `detach-window` moves a window; it is not server detach/reattach. |
| Worktree | Git worktree selected as launch cwd | Git, not Kitty, manages worktrees. |
| Integration | Shell integration, kittens, watchers, user variables | Extension facilities, not built-in Herdr agent detectors. |

Herdr's hierarchy is server session → workspace → tab → pane, with recognized agents attached to occupants. Kitty's hierarchy is process → OS window → tab → window, with session membership as an additional grouping. See Herdr concepts and Kitty glossary/sessions above.

### Herdr's agent surface has stronger semantics

Herdr separates raw pane operations from agent operations. `agent start` requires an available shell pane; it does not create layout. Agent commands accept a live agent name or hosting pane ID, not terminal IDs or bare agent-kind labels. Names are unique among live agents, match `[a-z][a-z0-9_-]{0,31}`, and are cleared on exit/release/replacement.

Lifecycle states include `working`, `blocked`, `idle`, `done`, and `unknown`. `idle` and `done` both mean ready for input; their distinction depends on whether completion was seen. CLI/API server state and individual TUI clients can differ. Explicit focus marks targets seen; reads do not. `unknown` is not completion.

`agent start` waits for detection/readiness, normally up to 30 seconds. Blocked startup can return `agent_not_ready` while retaining the name. `agent prompt` rejects recognized blocked UIs, submits paste plus Enter in order, and can wait for settled states. Its wait follows lifecycle, not a unique turn; a pre-existing active turn can satisfy it. Without an observed transition after a prompt from a non-working state, it can report `agent_prompt_stalled`. See the pinned Herdr skill and agent guide.

Kitty exposes terminal/process facts such as `foreground_processes`, `at_prompt`, `last_reported_cmdline`, `last_cmd_exit_status`, `in_alternate_screen`, and `user_vars` in the researched checkout. A persistent agent can be the same foreground process while working and while idle. Shell `at_prompt` does not describe an agent's input field. None of these fields is an agent-turn completion API. See `kitty/window.py:WindowDict`, `Window.as_dict`, and `kitty/rc/ls.py`.

## Transport, authorization, and targeting

### Herdr context

Herdr uses a socket API, mostly JSON CLI responses, and injected context including `HERDR_ENV`, `HERDR_PANE_ID`, `HERDR_SESSION`, `HERDR_SOCKET_PATH`, `HERDR_TAB_ID`, and `HERDR_WORKSPACE_ID`. Its skill requires `HERDR_ENV=1` before inspecting or controlling the session.

Public IDs such as `w1`, `w1:t1`, and `w1:p1` are opaque handles. Moving a pane across workspaces changes its workspace-qualified ID; callers should consume the returned new ID. Names and IDs are scoped to one server. Machine profiles are connection settings, not a cross-machine pane inventory. Selecting a machine in the TUI does not retarget a pane's inherited CLI context. See Herdr CLI reference and skill.

### Kitty context

Kitty selects transport in this order: explicit `--to`, inherited `KITTY_LISTEN_ON`, then the controlling terminal. An inherited endpoint can be `fd:NUMBER`; an execution tool can lose the descriptor even if its environment string survives. A process can also lack a controlling terminal. `KITTY_WINDOW_ID` alone cannot establish connectivity. See `kitty/remote_control.py` and the glossary.

External socket control is a documented Kitty capability. This skill deliberately requires `kitty` on `PATH` and execution from a Kitty terminal; it uses inherited context or an explicit endpoint for that context when the execution tool needs one. That prerequisite is a skill policy, not a limitation of Kitty itself. Retain the endpoint with target IDs and re-resolve after restart; the same numeric ID in another Kitty process is a different target.

`kitty @ ls` (also spelled `kitten @ ls`) returns OS windows → tabs → windows as JSON. Use it to resolve exact positive IDs, parent tabs, cwd, and processes. `ls --self`/`state:self` depend on valid caller context. Do not fall back to whatever is focused when the caller cannot be resolved.

The matching distinction is essential:

- `launch --match` selects tabs; `window_id:NUMBER` selects the tab containing that window.
- `launch --next-to` and `--source-window` select windows.
- `--next-to` is ignored when its match is outside the selected target tab.
- Tab `id:`/`title:` matching can fall back to matching a window; validate the intended tab first.
- Some commands affect every match, others the first match. Validate single-target cardinality before single-target writes.

See `kitty/rc/base.py`, `kitty/rc/launch.py`, and installed matching help. Do not substitute negative IDs, tab positions, or recent/focused selectors for stable targets.

### Authorization and optional setup

| `allow_remote_control` | Meaning |
|---|---|
| `no` | Disabled globally |
| `password` | Password authorization |
| `socket` | Accept socket requests; authorize TTY requests by password |
| `socket-only` | Accept socket requests; reject TTY requests |
| `yes` | Accept requests globally |

Per-window `launch --allow-remote-control` can grant access without globally enabling it. `--remote-control-password` can restrict that grant. Global password rules can scope permitted action names; an unknown password can produce an interactive authorization prompt. Passwords can come from `--password-file` or an environment variable, defaulting to `KITTY_RC_PASSWORD`. Never echo them during discovery. See remote-control docs and options definitions.

For a user-requested socket setup, a portable example is:

```conf
allow_remote_control socket-only
listen_on unix:${HOME}/.local/run/kitty-{kitty_pid}
```

Create the parent directory first. `listen_on` supports environment expansion and otherwise appends a PID unless `{kitty_pid}` is supplied. Changing it requires a new instance; config reload cannot change the listener. This is setup reference, not an instruction to rewrite existing configuration during routine control. Password-based control over SSH also needs the Kitty public key context; the SSH kitten supplies it. See `kitty/options/definition.py` and remote-control docs.

## Capability and command mapping

| Workflow | Herdr | Kitty native surface |
|---|---|---|
| List topology | Workspace/tab/pane lists | `ls` |
| Current pane | `pane current --current` | Verified `KITTY_WINDOW_ID`, `ls --self` |
| Create terminal | `pane split` | `launch --type=window` |
| Create tab | `tab create` | `launch --type=tab --tab-title NAME` |
| Create project container | `workspace create` | Session/project setup or OS window; not exact |
| Run a program | `pane run` | Direct `launch PROGRAM ARG...`; existing shell input only after verification |
| Start an agent | `agent start` | `launch AGENT ARG...`; readiness must be observed |
| Read output | `pane read`, `agent read` | `get-text` |
| Send literal text | `pane send-text` | `send-text --stdin` or `--from-file` |
| Send keys | Pane/agent `send-keys` | `send-key` |
| Submit and await a turn | `agent prompt --wait` | No direct equivalent |
| Wait for output | `pane wait-output` | Bounded `get-text` polling |
| Wait for process exit | Separate lifecycle/output waits | `launch --wait-for-child-to-exit` |
| Run without a pane | Other process workflows | `run` or `launch --type=background` |
| Focus | Pane/tab/agent focus | `focus-window`, `focus-tab` |
| Rename/tag | Pane/tab/agent names | `set-window-title`, `set-tab-title`, `set-user-vars` |
| Resize | `pane resize` | `resize-window` within layout constraints |
| Move pane | `pane move` | `detach-window` |
| Move tab to OS window | No exact workspace-independent equivalent | `detach-tab` |
| Change layout | Split/layout operations | `goto-layout`, `set-enabled-layouts`, actions |
| Close work | Pane/tab/workspace close | `close-window`, `close-tab`, session-close action |
| Worktrees | `worktree` group | External Git commands |
| Detach/reattach | Server/client operations | No persistent-server equivalent |
| Event subscriptions | Socket subscription/streaming API | Watcher callbacks; not an equivalent CLI stream |

Kitty operations in this table use the `kitty @` prefix and the selected endpoint. The original research used the equivalent `kitten @` spelling; `kitty @` avoids requiring a separate client executable on `PATH`. Authority: installed help and `kitty/rc/*.py`. Herdr authority: tagged CLI/socket documentation.

## Native workflows and operational differences

### Launch and layout

The skill's sibling recipe combines a tab selector, a source-window selector, and `--next-to`. This is necessary when user focus differs from the source tab. `--keep-focus` preserves current focus. `--cwd "$task_cwd"` specifies a host path; `--cwd current` inherits the source context and can clone an SSH-kitten connection. Do not treat these as interchangeable.

With a literal cwd, use `--add-to-session .` to join the specified source's session. Source-session inheritance normally accompanies source-derived cwd modes. Session membership does not update the saved session file. See `kitty/launch.py` and installed launch help.

`launch` prints a plain window ID. `--no-response` suppresses it. `--wait-for-child-to-exit` prints the child's exit code or symbolic signal instead. `--type=background` creates no terminal window. Avoid accidentally interpreting these different results as the same ID format.

`--location=split` chooses geometry in `splits`; `vsplit` creates side-by-side panes and `hsplit` stacked panes. Other layouts arrange windows according to their own rules. Do not promise a directional split in `tall`, `grid`, or `stack` without an appropriate layout change. See layouts docs and `kitty/launch.py`.

### Reading output

Herdr read sources include `visible`, `recent`, `recent-unwrapped`, and `detection`, with optional line counts and ANSI formatting. Its unwrapped mode joins soft wraps; detection is its agent detector's snapshot. Increasing line count cannot recover alternate-screen content discarded by the application/terminal.

Kitty's `get-text --extent screen` reads the current screen; `all` includes available history. Command-output extents require shell integration. `--ansi` preserves formatting and `--add-wrap-markers` identifies soft wraps. Kitty has no equivalent `--lines` argument or agent-detection extent. Bound output locally if needed. See `kitty/rc/get_text.py` and `kitty/window.py:as_text`.

When the alternate screen is active, `as_text` disables history for that screen. Newer `alternate` extents select the other screen; they do not recover a discarded transcript. These extents are absent from installed 0.47.4 `get-text` help. Prefer a native transcript or an output file when screen capture is insufficient.

### Prompt delivery

Herdr understands recognized agent occupants and blocked UIs; its prompt operation orders bracketed paste and Enter. Kitty supplies lower-level input primitives. Use exact targets and read the intended input surface first, then transfer raw prompt text through `--stdin`/`--from-file` with `--bracketed-paste=auto`, let the application process it, and send `enter` separately.

Positional `send-text` arguments interpret backslash escapes. Raw transfer preserves intended quotes, backslashes, Unicode, and newlines. The local prompt file is consumed by the `kitten` client; it need not exist on the Kitty host.

Both `send-text` and `send-key` explicitly do not report remote errors, including no-match delivery. Successful CLI exit is not an acknowledgement and does not prove a turn started. Re-read the window before retrying uncertain input. Two calls are not an atomic prompt transaction. See `kitty/rc/send_text.py` and `kitty/rc/send_key.py`.

### Commands, completion, and timeouts

For commands in new panes, launch the executable directly. `--hold` starts a shell after the command exits; it is not merely a frozen terminal. If process completion is desired, `--wait-for-child-to-exit --response-timeout SECONDS` waits and prints the child's status. Its default timeout is one day, so choose a task-appropriate explicit bound. The printed child status and the remote-control invocation's exit status are different things. See `kitty/rc/launch.py`.

`kitten @ run` executes on the Kitty host, forwarding stdout/stderr and propagating the executed program's exit status. It does not run in an existing interactive shell. See `kitty/rc/run.py`.

Neither child exit waiting nor shell status detects a turn ending in a persistent agent TUI. Use bounded observations and fresh task-specific evidence. Herdr's output wait searches existing snapshots immediately, so even there an old marker can satisfy a wait. Baseline comparison or a unique task marker avoids mistaking old output for new completion. On timeout, report state and inspect before resubmitting or relaunching; the original process may still be running.

## Persistence and extensions

Herdr detach/reattach preserves processes while its server remains running. Server restart restores layout/cwd and optionally history or supported native agent sessions; it is not universal process resurrection. Experimental handoff is distinct from machine profile setup. See Herdr session-state documentation.

Kitty session files recreate windows, tabs, layout, cwd, and launch commands. `save_as_session` and `ls --output-format=session` can produce descriptions. They do not checkpoint process memory or arbitrary agent conversations. Agent resume must use a verified native agent mechanism. See Kitty sessions documentation and `kitty/rc/ls.py`.

`detach-window --target-tab ... --stay-in-tab` moves a live terminal. Close operations can terminate processes. Track task-owned windows, and never equate moving with persistent server detach. See `kitty/rc/detach_window.py`, `close_window.py`, and `close_tab.py`.

Watchers can observe close, focus, and shell command start/stop. User variables can label tasks. Building a true agent integration would require additional detection/state logic; a task label alone provides neither unique agent identity nor automatic lifecycle cleanup. The initial skill uses native commands without a simulated Herdr API.

## Validation coverage

The skill passed the skill-creator frontmatter validator. Example flags were checked against installed help; shell blocks passed Bash and Zsh syntax checks. Local reference links resolve, and the deliverables contain no host-specific home paths.

The original runtime verification used installed **Kitty 0.47.4** in a dedicated instance with an isolated Unix socket and no user configuration. All eleven scenario checks passed:

| Scenario | Observed result |
|---|---|
| Source tab differs from active tab | Launch returns a plain numeric ID, creates in the specified source tab, and preserves the other active tab. |
| Literal prompt transfer | Quotes, backslashes, shell metacharacters, Unicode, and newlines arrive unchanged inside bracketed-paste framing; separate Enter submits them. |
| Missing window | `send-text` and `send-key` exit successfully; `ls --match` and `get-text` report no matching window. |
| Missing endpoint | Explicit socket connection fails without falling back to another instance. |
| Existing non-splits layout | Ordinary sibling launch preserves `tall` and the active tab. |
| Finite command with hold | Output remains readable after command exit. |
| Child exit status | A child exit code of 7 is printed while the remote-control invocation exits with status 0. |
| Bounded launch timeout | Timeout leaves exactly one discoverable child running; no duplicate launch is needed. |
| Window/tab management | Exact-ID rename, resize, move, and focus commands operate successfully on owned targets. |
| Alternate-screen capture | `get-text --extent all` exposes current alternate content, not earlier primary-screen content. |
| Cleanup | Closing test-owned windows leaves only the isolated root; closing that root ends the test instance. |

The input fixture collected bytes from a raw terminal and accounted for bracketed-paste delimiters, including an empty final paste chunk. Screen checks used bounded polling because screen rendering can lag input receipt. These observations support checking application evidence after submission rather than treating immediate CLI success as delivery acknowledgement.

Agent-specific readiness and turn completion depend on the actual agent UI or native artifacts. A terminal input/output fixture can validate transport, but cannot certify every agent's prompt semantics. Remote SSH context, password grants, and saved-session restore require their own configured environments when those workflows are exercised.


The subsequent relocation to `skills/kitty-remote-control` changed the prerequisite to Kitty-terminal execution with `kitty` on `PATH`, removed the source-clone requirement, and added optional installed-documentation lookup with release-matched web fallback. Read-only validation confirmed `kitty @` help dispatch, browser-free URL resolution, the installed HTML and RST files, and the online fallback. The original eleven GUI runtime scenarios were not repeated for this documentation-only revision.
