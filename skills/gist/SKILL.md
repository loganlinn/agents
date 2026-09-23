---
name: gist
description: Create a GitHub gist from a specified scope or the previous assistant response. Explicit invocation only.
---

# Gist

Run only when the user explicitly invokes `$gist`. Invocation authorizes creating one gist from the selected content.

1. Use the scope in the invoking prompt: supplied text, named files, selected sections, or referenced conversation content. If no scope is given, use the last assistant final response before the invocation. Ask for clarification only if the source is unavailable or ambiguous.
2. Prepare the content:
   - For fenced code, extract the block contents verbatim, preserving indentation and removing the fence markers and surrounding commentary.
   - Put distinct blocks in separate files within the same gist unless the user requests otherwise. Use supplied filenames, or infer descriptive names and extensions from the content or fence language; fall back to `snippet.txt` with numeric suffixes as needed.
   - For prose, or an explicit request to include explanations, preserve the requested Markdown in `response.md`, including embedded code fences. Explicit scope and formatting requests take precedence over these defaults.
3. Write the selected content to temporary files using literal writes so shell substitutions cannot alter or execute it. Check `gh auth status --hostname github.com`; if authentication is unavailable, report the blocker.
4. Create the gist with `gh gist create --desc 'short description' -- <file>...`. Use secret visibility by default; add `--public` only when requested. If a create attempt has an uncertain outcome, check recent gists before retrying to avoid duplicates.
5. Return the created gist URL. If creation fails, report the error instead.
