# Reading Kitty documentation without a source checkout

Use `kitty --version` and `kitty @ SUBCOMMAND --help` first. They describe the installed executable and require neither a source clone nor a browser. The following documentation lookups are read-only and do not require remote-control access.

## Optional local lookup through Kitty

The `show_kitty_doc` action calls `kitty.utils.docs_url(topic)` and passes its result to the application's URL opener. It has no print-only option. Do not invoke the action through remote control just to obtain documentation: that opens a browser.

Instead, the installed Kitty Python runtime can call the same resolver and print the result:

```sh
kitty +runpy 'from kitty.utils import docs_url; print(docs_url("remote-control"))'
```

Use topics such as `launch`, `layouts`, or `sessions` for other pages. This prints a `file://.../remote-control.html` URL when Kitty resolves a local documentation root, otherwise a URL on `https://sw.kovidgoyal.net/kitty/`. It does not open a browser or need a separately installed Python interpreter.

`kitty.constants.local_docs()` resolves the installation layout instead of requiring the caller to guess a platform-specific directory. The researched implementation handles the macOS application bundle, Linux installation prefixes, source builds, and common package locations. Documentation can be omitted by packagers, and some branches construct a path without checking that the requested file exists. The returned URL is a candidate: verify a local file before reading it.

For agent-readable RST, check whether the installed documentation includes Sphinx's source copy:

```sh
kitty +runpy 'from pathlib import Path; from kitty.constants import local_docs; root = local_docs(); p = Path(root) / "_sources/remote-control.rst.txt" if root else None; print(str(p) if p is not None and p.is_file() else "")'
```

Read the printed file directly. If no source file is available but the HTML file exists, use a file reader or HTML-to-text extraction. For a `file:` URL, decode its path with URL parsing rather than treating the whole URL as a filesystem path. Local documentation paths belong to the machine running `kitty`; a remote file URL is not a local file on the controller.

These Python helpers are internal interfaces, not a guaranteed stable public documentation CLI. They were verified with Kitty 0.47.4 on macOS and their platform branches inspected in source; Linux execution was not tested. If `+runpy`, either import, or local file access fails, use the web fallback below. If a source checkout in the current directory shadows the installed Python modules, retry the read-only lookup from a neutral directory. Do not require users to install source or documentation packages just for this lookup.

## Fetch the installed release's documentation

Read the release number from:

```sh
kitty --version
```

Use a web-fetch tool to read this raw source URL, substituting that observed release number:

```text
https://raw.githubusercontent.com/kovidgoyal/kitty/v{version}/docs/remote-control.rst
```

For example, `kitty 0.47.4` maps to:

<https://raw.githubusercontent.com/kovidgoyal/kitty/v0.47.4/docs/remote-control.rst>

Likewise fetch `docs/launch.rst`, `docs/layouts.rst`, or `docs/sessions.rst` only when relevant. Sphinx source can contain directives or references to generated material; use installed `kitty @ SUBCOMMAND --help` for the actual remote-command flags. If implementation details are needed, the same release tag provides `kitty/rc/COMMAND.py`, with hyphens in CLI command names replaced by underscores.

Development builds or distribution-patched builds may not have an exact upstream tag. If the matching release URL is unavailable, report that limitation and use the current official [remote-control documentation](https://sw.kovidgoyal.net/kitty/remote-control/) with installed help as the syntax authority. Do not silently treat current web documentation as matching an older binary. The resolver's HTTPS fallback also points to the current website, not a version-pinned manual.

## Implementation references

- [Action documentation](https://sw.kovidgoyal.net/kitty/actions/#action-show_kitty_doc): `show_kitty_doc` prefers local documentation.
- [Kitty 0.47.4 entry points](https://github.com/kovidgoyal/kitty/blob/v0.47.4/kitty/entry_points.py): `+runpy` executes code inside Kitty's runtime.
- [Kitty 0.47.4 constants](https://github.com/kovidgoyal/kitty/blob/v0.47.4/kitty/constants.py): `local_docs()` resolves the installed documentation root.
- [Kitty 0.47.4 utilities](https://github.com/kovidgoyal/kitty/blob/v0.47.4/kitty/utils.py): `docs_url()` constructs the file/web URL and optional fragment.
- [Kitty 0.47.4 window actions](https://github.com/kovidgoyal/kitty/blob/v0.47.4/kitty/window.py): `show_kitty_doc()` opens the resolved URL.
