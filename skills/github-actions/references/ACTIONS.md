# Creating Custom Actions Reference

Guide to creating JavaScript, Docker, and composite actions.

## Action Types

| Type | Best For | Runner |
|------|----------|--------|
| JavaScript | Fast startup, cross-platform | Any |
| Docker | Custom environment, any language | Linux only |
| Composite | Combining existing actions/steps | Any |

## Metadata File (action.yml)

Every action requires `action.yml` or `action.yaml` in the action's root directory.

### Basic Structure

```yaml
name: 'My Action'
description: 'What my action does'
author: 'Your Name'

inputs:
  input-name:
    description: 'Description of input'
    required: true
    default: 'default value'

outputs:
  output-name:
    description: 'Description of output'

runs:
  using: 'node20'  # or 'composite' or 'docker'
  main: 'dist/index.js'

branding:
  icon: 'check-circle'
  color: 'green'
```

## Inputs

```yaml
inputs:
  api-key:
    description: 'API key for authentication'
    required: true

  environment:
    description: 'Target environment'
    required: false
    default: 'production'

  config-path:
    description: 'Path to config file'
    required: false
    deprecationMessage: 'Use config-file instead'
```

### Input Properties

| Property | Required | Description |
|----------|----------|-------------|
| `description` | Yes | What the input is for |
| `required` | No | Whether input is required (default: false) |
| `default` | No | Default value if not provided |
| `deprecationMessage` | No | Warning when input is used |

### Accessing Inputs

In JavaScript:
```javascript
const core = require('@actions/core');
const apiKey = core.getInput('api-key', { required: true });
const environment = core.getInput('environment');
```

In composite actions:
```yaml
steps:
  - run: echo "${{ inputs.api-key }}"
```

In Docker:
```yaml
runs:
  using: 'docker'
  image: 'Dockerfile'
  args:
    - ${{ inputs.api-key }}
```

Environment variable: `INPUT_API-KEY` (uppercase, dashes preserved)

## Outputs

### JavaScript/Docker Actions

```yaml
outputs:
  result:
    description: 'The result of the operation'
  version:
    description: 'Detected version'
```

Set output in JavaScript:
```javascript
const core = require('@actions/core');
core.setOutput('result', 'success');
core.setOutput('version', '1.0.0');
```

### Composite Actions

```yaml
outputs:
  result:
    description: 'The result'
    value: ${{ steps.my-step.outputs.result }}

runs:
  using: 'composite'
  steps:
    - id: my-step
      run: echo "result=success" >> "$GITHUB_OUTPUT"
      shell: bash
```

## JavaScript Actions

### Minimal Setup

```yaml
# action.yml
name: 'JavaScript Action'
description: 'A JavaScript action'
inputs:
  name:
    description: 'Name to greet'
    required: true
outputs:
  greeting:
    description: 'The greeting message'
runs:
  using: 'node20'
  main: 'dist/index.js'
```

### Node.js Versions

- `node20` - Node.js 20
- `node24` - Node.js 24

### Pre and Post Scripts

```yaml
runs:
  using: 'node20'
  pre: 'dist/setup.js'      # Runs before main
  pre-if: runner.os == 'Linux'
  main: 'dist/index.js'
  post: 'dist/cleanup.js'   # Runs after main
  post-if: always()
```

### Basic JavaScript Implementation

```javascript
// index.js
const core = require('@actions/core');
const github = require('@actions/github');

async function run() {
  try {
    // Get inputs
    const name = core.getInput('name', { required: true });

    // Do work
    const greeting = `Hello, ${name}!`;
    console.log(greeting);

    // Set outputs
    core.setOutput('greeting', greeting);

    // Access context
    const payload = github.context.payload;
    console.log(`Event: ${github.context.eventName}`);

  } catch (error) {
    core.setFailed(error.message);
  }
}

run();
```

### Common @actions packages

```javascript
const core = require('@actions/core');      // Inputs, outputs, logging
const github = require('@actions/github');  // GitHub API, context
const exec = require('@actions/exec');      // Run commands
const io = require('@actions/io');          // File operations
const cache = require('@actions/cache');    // Caching
const artifact = require('@actions/artifact'); // Artifacts
const glob = require('@actions/glob');      // File patterns
```

### Core API

```javascript
const core = require('@actions/core');

// Inputs
const input = core.getInput('name');
const required = core.getInput('key', { required: true });
const trimmed = core.getInput('value', { trimWhitespace: true });
const multiline = core.getMultilineInput('items');
const bool = core.getBooleanInput('enabled');

// Outputs
core.setOutput('result', value);

// Logging
core.debug('Debug message');
core.info('Info message');
core.warning('Warning message');
core.error('Error message');
core.notice('Notice annotation');

// Grouping
core.startGroup('Group name');
console.log('Grouped output');
core.endGroup();

// Masking secrets
core.setSecret(sensitiveValue);

// Fail the action
core.setFailed('Error message');

// Export variable
core.exportVariable('MY_VAR', 'value');

// Add to PATH
core.addPath('/path/to/bin');

// Save state (for post scripts)
core.saveState('key', 'value');
const state = core.getState('key');
```

### GitHub API Access

```javascript
const github = require('@actions/github');

// Context
const { context } = github;
console.log(context.repo.owner);      // Repository owner
console.log(context.repo.repo);       // Repository name
console.log(context.sha);             // Commit SHA
console.log(context.ref);             // Git ref
console.log(context.eventName);       // Event name
console.log(context.payload);         // Event payload

// Octokit client
const token = core.getInput('github-token');
const octokit = github.getOctokit(token);

// API calls
const { data: issue } = await octokit.rest.issues.create({
  owner: context.repo.owner,
  repo: context.repo.repo,
  title: 'New issue',
  body: 'Issue body'
});
```

### Build and Bundle

Use @vercel/ncc to bundle:

```bash
npm install @vercel/ncc
npx ncc build src/index.js -o dist
```

Or use esbuild:

```bash
npm install esbuild
npx esbuild src/index.js --bundle --platform=node --outfile=dist/index.js
```

## Composite Actions

Combine multiple steps into a reusable action.

```yaml
# action.yml
name: 'Setup and Build'
description: 'Setup Node.js and build project'

inputs:
  node-version:
    description: 'Node.js version'
    required: false
    default: '20'
  working-directory:
    description: 'Working directory'
    required: false
    default: '.'

outputs:
  build-version:
    description: 'Built version'
    value: ${{ steps.version.outputs.value }}

runs:
  using: 'composite'
  steps:
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: 'npm'
        cache-dependency-path: ${{ inputs.working-directory }}/package-lock.json

    - name: Install dependencies
      run: npm ci
      shell: bash
      working-directory: ${{ inputs.working-directory }}

    - name: Build
      run: npm run build
      shell: bash
      working-directory: ${{ inputs.working-directory }}

    - name: Get version
      id: version
      run: echo "value=$(node -p "require('./package.json').version")" >> "$GITHUB_OUTPUT"
      shell: bash
      working-directory: ${{ inputs.working-directory }}
```

### Composite Step Properties

| Property | Required | Description |
|----------|----------|-------------|
| `run` | No* | Command to run |
| `uses` | No* | Action to use |
| `shell` | Yes for `run` | Shell (bash, pwsh, etc.) |
| `with` | No | Action inputs |
| `env` | No | Environment variables |
| `if` | No | Condition |
| `id` | No | Step identifier |
| `name` | No | Display name |
| `working-directory` | No | Working directory |
| `continue-on-error` | No | Don't fail on error |

*One of `run` or `uses` is required per step.

### Access Action Path

```yaml
runs:
  using: 'composite'
  steps:
    - run: ${{ github.action_path }}/scripts/build.sh
      shell: bash

    - run: cat $GITHUB_ACTION_PATH/config.json
      shell: bash
```

## Docker Actions

### Dockerfile-based

```yaml
# action.yml
name: 'Docker Action'
description: 'Action using Docker'

inputs:
  name:
    description: 'Name to greet'
    required: true

runs:
  using: 'docker'
  image: 'Dockerfile'
  args:
    - ${{ inputs.name }}
  env:
    MY_VAR: 'value'
```

```dockerfile
# Dockerfile
FROM alpine:3.18

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
```

```bash
#!/bin/sh
# entrypoint.sh
echo "Hello, $1!"
echo "result=success" >> "$GITHUB_OUTPUT"
```

### Pre-built Image

```yaml
runs:
  using: 'docker'
  image: 'docker://alpine:3.18'
  args:
    - ${{ inputs.name }}
```

### Docker Properties

```yaml
runs:
  using: 'docker'
  image: 'Dockerfile'
  env:
    MY_VAR: 'value'
  entrypoint: 'main.sh'           # Override ENTRYPOINT
  pre-entrypoint: 'setup.sh'      # Run before main
  post-entrypoint: 'cleanup.sh'   # Run after main
  args:
    - '--flag'
    - ${{ inputs.value }}
```

### Docker Credentials

```yaml
runs:
  using: 'docker'
  image: 'docker://myregistry.com/myimage:latest'
  credentials:
    username: ${{ inputs.registry-user }}
    password: ${{ inputs.registry-token }}
```

## Branding

For GitHub Marketplace listing.

```yaml
branding:
  icon: 'check-circle'
  color: 'green'
```

Colors: `white`, `black`, `yellow`, `blue`, `green`, `orange`, `red`, `purple`, `gray-dark`

Icons: Any [Feather icon](https://feathericons.com/) except: `coffee`, `columns`, `divide-circle`, `divide-square`, `divide`, `frown`, `hexagon`, `key`, `meh`, `mouse-pointer`, `smile`, `tool`, `x-octagon`

## Using Actions

### From Public Repository

```yaml
- uses: owner/repo@v1           # Major version tag
- uses: owner/repo@v1.2.3       # Specific version
- uses: owner/repo@main         # Branch
- uses: owner/repo@abc123       # Commit SHA
- uses: owner/repo/path@v1      # Subdirectory
```

### From Same Repository

```yaml
- uses: ./.github/actions/my-action
```

### From Private Repository

Requires checkout with token that has access:

```yaml
- uses: actions/checkout@v5
  with:
    repository: owner/private-repo
    path: .github/actions/private-action
    token: ${{ secrets.PAT }}

- uses: ./.github/actions/private-action
```

## Publishing

### Version Tags

```bash
# Create release tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Update major version tag
git tag -fa v1 -m "Update v1 tag"
git push origin v1 --force
```

### GitHub Marketplace

1. Action must be in public repository
2. `action.yml` must have `name`, `description`, `runs`
3. Add `branding` for better visibility
4. Create a release

### Best Practices

1. **Semantic versioning** - Use v1, v1.0, v1.0.0
2. **Pin major versions** - Keep v1 pointing to latest v1.x
3. **Document inputs/outputs** - Clear descriptions
4. **Fail fast** - Use `core.setFailed()` on errors
5. **Mask secrets** - Use `core.setSecret()`
6. **Bundle dependencies** - Single file with ncc/esbuild
7. **Test thoroughly** - Unit tests + integration tests
