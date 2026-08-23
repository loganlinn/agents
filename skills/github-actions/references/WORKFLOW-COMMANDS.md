# Workflow Commands Reference

Workflow commands use `echo` with `::command::` syntax to communicate with the runner.
Commands and parameter names are case insensitive.

## Annotation Commands

All annotation commands support the same optional parameters:

| Parameter   | Description              |
|-------------|--------------------------|
| `file`      | Filename                 |
| `line`      | Start line (1-based)     |
| `endLine`   | End line                 |
| `col`       | Start column (1-based)   |
| `endColumn` | End column               |
| `title`     | Custom title             |

### ::debug::

Prints a debug message. Only visible when `ACTIONS_STEP_DEBUG` secret is `true`.

```bash
echo "::debug::Set the Octocat variable"
```

### ::notice::

Creates a notice annotation in the log and optionally on a file.

```bash
echo "::notice file=app.js,line=1,col=5,endColumn=7::Missing semicolon"
```

### ::warning::

Creates a warning annotation.

```bash
echo "::warning file=app.js,line=1,col=5,endColumn=7,title=Lint Issue::Missing semicolon"
```

### ::error::

Creates an error annotation.

```bash
echo "::error file=app.js,line=1,col=5,endColumn=7,title=Build Error::Missing semicolon"
```

Full workflow example with annotations:

```yaml
steps:
  - name: Annotate build error
    run: echo "::error file=app.js,line=10::Syntax error"

  - name: Annotate deprecation
    run: echo "::warning file=lib/old.js,line=3,title=Deprecated::Use newMethod() instead"

  - name: Annotate info
    run: echo "::notice file=README.md,line=1::Consider updating docs"
```

## ::group:: / ::endgroup::

Creates an expandable group in the log output.

```yaml
steps:
  - name: Grouped log lines
    run: |
      echo "::group::My title"
      echo "Inside group"
      echo "::endgroup::"
```

## ::add-mask::

Masks a value so it appears as `***` in logs. The value is treated as a secret.

```bash
echo "::add-mask::Mona The Octocat"
```

Mask an environment variable:

```yaml
jobs:
  example:
    runs-on: ubuntu-latest
    env:
      MY_NAME: "Mona The Octocat"
    steps:
      - run: echo "::add-mask::$MY_NAME"
```

Generate, mask, and output a secret within a single job:

```yaml
steps:
  - id: sets-a-secret
    run: |
      the_secret=$((RANDOM))
      echo "::add-mask::$the_secret"
      echo "secret-number=$the_secret" >> "$GITHUB_OUTPUT"
  - name: Use that secret output (protected by a mask)
    run: echo "the secret number is ${{ steps.sets-a-secret.outputs.secret-number }}"
```

Register the mask **before** outputting the value to logs or other workflow commands.

## ::stop-commands:: / Resume

Stops processing workflow commands. Useful for logging raw output that contains `::` syntax.

```yaml
steps:
  - name: Disable workflow commands
    run: |
      echo '::warning:: This IS rendered as a warning.'
      stopMarker=$(uuidgen)
      echo "::stop-commands::$stopMarker"
      echo '::warning:: This is NOT rendered as a warning.'
      echo "::$stopMarker::"
      echo '::warning:: This IS rendered as a warning again.'
```

Use a unique random token for the stop marker on each run.

## Environment Files

The runner provides temporary files for setting outputs, env vars, path entries, summaries, and state.
Write to them using `>>` (append). Use UTF-8 encoding.

## GITHUB_OUTPUT (Step Outputs)

Set output parameters that other steps can read via `steps.<id>.outputs.<name>`.
The step must have an `id`.

```bash
echo "{name}={value}" >> "$GITHUB_OUTPUT"
```

```yaml
steps:
  - name: Set color
    id: color-selector
    run: echo "SELECTED_COLOR=green" >> "$GITHUB_OUTPUT"

  - name: Get color
    env:
      SELECTED_COLOR: ${{ steps.color-selector.outputs.SELECTED_COLOR }}
    run: echo "The selected color is $SELECTED_COLOR"
```

### Multiline output values

Use a heredoc-style delimiter:

```text
{name}<<{delimiter}
{value}
{delimiter}
```

```yaml
steps:
  - name: Set multiline output
    id: multi
    run: |
      {
        echo 'RESULT<<EOF'
        curl https://example.com
        echo EOF
      } >> "$GITHUB_OUTPUT"
```

The delimiter must not appear on a line by itself within the value.

## GITHUB_ENV (Environment Variables)

Set environment variables available to all subsequent steps in the job.

```bash
echo "{name}={value}" >> "$GITHUB_ENV"
```

The step that writes the variable does **not** have access to the new value; only subsequent steps do.

```yaml
steps:
  - name: Set the value
    run: echo "action_state=yellow" >> "$GITHUB_ENV"

  - name: Use the value
    run: printf '%s\n' "$action_state"  # outputs 'yellow'
```

Store metadata like timestamps:

```yaml
steps:
  - name: Store build timestamp
    run: echo "BUILD_TIME=$(date +'%T')" >> $GITHUB_ENV

  - name: Deploy using stored timestamp
    run: echo "Deploying at $BUILD_TIME"
```

### Multiline environment variables

```text
{name}<<{delimiter}
{value}
{delimiter}
```

```yaml
steps:
  - name: Set multiline env var
    run: |
      {
        echo 'JSON_RESPONSE<<EOF'
        curl https://example.com
        echo EOF
      } >> "$GITHUB_ENV"
```

### Restrictions

- Cannot overwrite `GITHUB_*` or `RUNNER_*` default variables.
- Cannot set `NODE_OPTIONS` via `GITHUB_ENV` (security restriction).

## GITHUB_STEP_SUMMARY (Job Summaries)

Append GitHub Flavored Markdown to `GITHUB_STEP_SUMMARY` to display on the workflow run summary page.
Each step has its own isolated summary. Max 1MiB per step. Max 20 step summaries per job.

```bash
echo "{markdown content}" >> $GITHUB_STEP_SUMMARY
```

### Basic example

```bash
echo "### Hello world! :rocket:" >> $GITHUB_STEP_SUMMARY
```

### Multiline markdown

```yaml
- name: Generate list using Markdown
  run: |
    echo "This is the lead in sentence for the list" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "- Lets add a bullet point" >> $GITHUB_STEP_SUMMARY
    echo "- Lets add a second bullet point" >> $GITHUB_STEP_SUMMARY
    echo "- How about a third one?" >> $GITHUB_STEP_SUMMARY
```

### Table example

```yaml
- name: Test results summary
  run: |
    echo "### Test Results" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "| Suite | Passed | Failed | Skipped |" >> $GITHUB_STEP_SUMMARY
    echo "|-------|--------|--------|---------|" >> $GITHUB_STEP_SUMMARY
    echo "| Unit  | 142    | 0      | 3       |" >> $GITHUB_STEP_SUMMARY
    echo "| E2E   | 38     | 2      | 0       |" >> $GITHUB_STEP_SUMMARY
```

### Image in summary

```yaml
- name: Add image to summary
  run: |
    echo "### Build Badge" >> $GITHUB_STEP_SUMMARY
    echo '![Status](https://img.shields.io/badge/build-passing-green)' >> $GITHUB_STEP_SUMMARY
```

### Heredoc for larger summaries

```yaml
- name: Write summary
  run: |
    cat >> $GITHUB_STEP_SUMMARY << 'EOF'
    ### Deployment Summary

    | Field       | Value                     |
    |-------------|---------------------------|
    | Environment | production                |
    | Version     | v1.2.3                    |
    | Commit      | abc1234                   |

    **Status:** Deployed successfully.
    EOF
```

### Overwrite summary (use `>` instead of `>>`)

```yaml
- name: Overwrite summary
  run: |
    echo "Adding some Markdown content" >> $GITHUB_STEP_SUMMARY
    echo "Replacing with new content." > $GITHUB_STEP_SUMMARY
```

### Delete summary

```yaml
- name: Delete all summary content
  run: rm $GITHUB_STEP_SUMMARY
```

Summaries auto-mask secrets. After a step completes, its summary is uploaded and cannot be modified by later steps.

## GITHUB_PATH (Add to PATH)

Prepend a directory to `PATH` for all subsequent actions in the current job.
The running step does not see the updated PATH.

```bash
echo "$HOME/.local/bin" >> "$GITHUB_PATH"
```

```yaml
steps:
  - name: Add custom tool to PATH
    run: echo "$HOME/.local/bin" >> "$GITHUB_PATH"

  - name: Use custom tool
    run: my-custom-tool --version
```

## GITHUB_STATE (Pre/Post Action State)

Share state between a custom action's `pre:`, `main:`, and `post:` lifecycle hooks.
Only available within actions (not in workflow `run:` steps).
Saved values are accessible as `STATE_{name}` environment variables.

### Writing state (JavaScript action)

```javascript
import * as fs from 'fs'
import * as os from 'os'

fs.appendFileSync(process.env.GITHUB_STATE, `processID=12345${os.EOL}`, {
  encoding: 'utf8'
})
```

### Reading state

```javascript
console.log("The running PID from the main action is: " + process.env.STATE_processID);
```

State written in `pre:` is only available in `pre:`. State written in `main:` is available in `post:`.

## Toolkit Function Mapping

| Toolkit function      | Workflow command / env file           |
|-----------------------|---------------------------------------|
| `core.debug`          | `::debug::`                           |
| `core.notice`         | `::notice::`                          |
| `core.warning`        | `::warning::`                         |
| `core.error`          | `::error::`                           |
| `core.startGroup`     | `::group::`                           |
| `core.endGroup`       | `::endgroup::`                        |
| `core.setSecret`      | `::add-mask::`                        |
| `core.setCommandEcho` | `::echo::`                            |
| `core.setOutput`      | `GITHUB_OUTPUT` file                  |
| `core.exportVariable` | `GITHUB_ENV` file                     |
| `core.addPath`        | `GITHUB_PATH` file                    |
| `core.summary`        | `GITHUB_STEP_SUMMARY` file            |
| `core.saveState`      | `GITHUB_STATE` file                   |
| `core.getState`       | `STATE_{NAME}` env var                |
| `core.getInput`       | `INPUT_{NAME}` env var                |
| `core.isDebug`        | `RUNNER_DEBUG` env var                |
| `core.setFailed`      | `::error::` + `exit 1`               |

## PowerShell Notes

PowerShell 5.1 (`shell: powershell`) requires explicit UTF-8 encoding:

```yaml
- shell: powershell
  run: |
    "mypath" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
```

PowerShell Core 6+ (`shell: pwsh`) uses UTF-8 by default:

```yaml
- shell: pwsh
  run: |
    "mypath" >> $env:GITHUB_PATH
```

For all environment files in PowerShell, use `$env:GITHUB_OUTPUT`, `$env:GITHUB_ENV`, etc.
