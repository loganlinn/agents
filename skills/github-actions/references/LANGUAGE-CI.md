# Language CI/CD Reference

Setup, cache, test, and publish patterns per language.

## Node.js

### Setup and Cache (npm)

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'
  - run: npm ci
  - run: npm run build --if-present
  - run: npm test
```

### Setup and Cache (yarn)

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'yarn'
  - run: yarn --frozen-lockfile
  - run: yarn test
```

### Setup and Cache (pnpm)

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: pnpm/action-setup@0609f0983b7a228f052f81ef4c3d6510cae254ad
    with:
      version: 6.10.0
  - uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'pnpm'
  - run: pnpm install
  - run: pnpm test
```

### Matrix Build

```yaml
strategy:
  matrix:
    node-version: ['18.x', '20.x']

steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-node@v4
    with:
      node-version: ${{ matrix.node-version }}
      cache: 'npm'
  - run: npm ci
  - run: npm run build --if-present
  - run: npm test
```

### Private Registry

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-node@v4
    with:
      node-version: '20'
      registry-url: https://registry.npmjs.org
      scope: '@myorg'
  - run: npm ci
    env:
      NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### Publish to npm

Configure in workflow triggered by release or push to main. Use `setup-node`
with `registry-url` and authenticate via `NODE_AUTH_TOKEN`.

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-node@v4
    with:
      node-version: '20'
      registry-url: https://registry.npmjs.org
  - run: npm ci
  - run: npm publish
    env:
      NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

## Python

### Setup and Cache (pip)

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-python@v5
    with:
      python-version: '3.12'
      cache: 'pip'
  - run: pip install -r requirements.txt
```

Cache auto-detects `requirements.txt` (pip), `Pipfile.lock` (pipenv),
or `poetry.lock` (poetry).

### Matrix Build

```yaml
strategy:
  matrix:
    python-version: ["3.10", "3.11", "3.12", "3.13"]

steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-python@v5
    with:
      python-version: ${{ matrix.python-version }}
      cache: 'pip'
  - run: pip install -r requirements.txt
  - run: pytest
```

### Testing with pytest

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-python@v5
    with:
      python-version: '3.x'
  - run: |
      python -m pip install --upgrade pip
      pip install -r requirements.txt
  - name: Test with pytest
    run: |
      pip install pytest pytest-cov
      pytest tests.py --doctest-modules --junitxml=junit/test-results.xml --cov=com --cov-report=xml
```

### Testing with tox

```yaml
strategy:
  matrix:
    python: ["3.9", "3.11", "3.13"]

steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-python@v5
    with:
      python-version: ${{ matrix.python }}
  - run: pip install tox
  - run: tox -e py
```

### Linting with Ruff

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-python@v5
    with:
      python-version: '3.x'
  - run: pipx install ruff
  - run: ruff check --output-format=github --target-version=py39
  - run: ruff format --diff --target-version=py39
    continue-on-error: true
```

### Publish to PyPI (Trusted Publishing)

Uses OpenID Connect -- no API token needed. Requires PyPI trusted publisher
configuration for the repository.

```yaml
name: Upload Python Package

on:
  release:
    types: [published]

permissions:
  contents: read

jobs:
  release-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-python@v5
        with:
          python-version: "3.x"
      - run: |
          python -m pip install build
          python -m build
      - uses: actions/upload-artifact@v4
        with:
          name: release-dists
          path: dist/

  pypi-publish:
    runs-on: ubuntu-latest
    needs: release-build
    permissions:
      id-token: write
    environment:
      name: pypi
    steps:
      - uses: actions/download-artifact@v5
        with:
          name: release-dists
          path: dist/
      - uses: pypa/gh-action-pypi-publish@6f7e8d9c0b1a2c3d4e5f6a7b8c9d0e1f2a3b4c5d
```

## Java with Maven

### Setup and Cache

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-java@v4
    with:
      java-version: '17'
      distribution: 'temurin'
      cache: maven
  - run: mvn --batch-mode --update-snapshots verify
```

`setup-java` caches the `.m2` directory. Cache key is based on `pom.xml` hash.

### Specifying JDK Version and Architecture

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-java@v4
    with:
      java-version: '17'
      distribution: 'temurin'  # Also: 'zulu', 'adopt', 'corretto', 'microsoft'
      architecture: x64
```

### Build, Test, and Package Artifacts

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-java@v4
    with:
      java-version: '17'
      distribution: 'temurin'
      cache: maven
  - run: mvn --batch-mode --update-snapshots verify
  - run: mkdir staging && cp target/*.jar staging
  - uses: actions/upload-artifact@v4
    with:
      name: Package
      path: staging
```

### Deploy to Maven Central / GitHub Packages

Use `setup-java` with `server-id` for `settings.xml` generation, then
`mvn deploy` with credentials.

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-java@v4
    with:
      java-version: '17'
      distribution: 'temurin'
      cache: maven
      server-id: ossrh
      server-username: MAVEN_USERNAME
      server-password: MAVEN_PASSWORD
  - run: mvn --batch-mode deploy
    env:
      MAVEN_USERNAME: ${{ secrets.OSSRH_USERNAME }}
      MAVEN_PASSWORD: ${{ secrets.OSSRH_TOKEN }}
```

## Java with Gradle

### Setup and Cache

`gradle/actions/setup-gradle` caches Gradle user home by default.

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-java@v4
    with:
      java-version: '17'
      distribution: 'temurin'
  - uses: gradle/actions/setup-gradle@017a9effdb900e5b5b2fddfb590a105619dca3c3
  - run: ./gradlew build
```

### Build, Test, and Package Artifacts

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-java@v4
    with:
      java-version: '17'
      distribution: 'temurin'
  - uses: gradle/actions/setup-gradle@017a9effdb900e5b5b2fddfb590a105619dca3c3
  - run: ./gradlew build
  - uses: actions/upload-artifact@v4
    with:
      name: Package
      path: build/libs
```

### Publish with Gradle

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-java@v4
    with:
      java-version: '17'
      distribution: 'temurin'
  - uses: gradle/actions/setup-gradle@017a9effdb900e5b5b2fddfb590a105619dca3c3
  - run: ./gradlew publish
    env:
      MAVEN_USERNAME: ${{ secrets.OSSRH_USERNAME }}
      MAVEN_PASSWORD: ${{ secrets.OSSRH_TOKEN }}
```

## Go

### Setup and Cache

`setup-go` caches modules by default using `go.sum` hash.

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-go@v5
    with:
      go-version: '1.21.x'
  - run: go get .
  - run: go build -v ./...
  - run: go test
```

### Matrix Build

```yaml
strategy:
  matrix:
    go-version: ['1.20', '1.21.x']

steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-go@v5
    with:
      go-version: ${{ matrix.go-version }}
  - run: go build -v ./...
  - run: go test ./...
```

### Custom Cache Dependency Path

```yaml
- uses: actions/setup-go@v5
  with:
    go-version: '1.21.x'
    cache-dependency-path: subdir/go.sum
```

### Build and Upload Artifacts

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-go@v5
    with:
      go-version: '1.21.x'
  - run: go build -v -o myapp ./...
  - run: go test -json > TestResults.json
  - uses: actions/upload-artifact@v4
    with:
      name: Go-results
      path: TestResults.json
```

## Rust

### Setup and Cache

Rust is preinstalled on GitHub-hosted runners. Use `rustup` for version
management and `actions/cache` for dependency caching.

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/cache@v4
    with:
      path: |
        ~/.cargo/registry
        ~/.cargo/git
        target
      key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}
  - run: cargo build --release
  - run: cargo test --release
```

### Switch Toolchain

```yaml
steps:
  - uses: actions/checkout@v5
  - run: rustup override set nightly
  - run: cargo build
  - run: cargo test
```

### Build with Profile Matrix

```yaml
strategy:
  matrix:
    profile: [dev, release]

steps:
  - uses: actions/checkout@v5
  - uses: actions/cache@v4
    with:
      path: |
        ~/.cargo/registry
        ~/.cargo/git
        target
      key: ${{ runner.os }}-cargo-${{ matrix.profile }}-${{ hashFiles('**/Cargo.lock') }}
  - run: cargo build --profile ${{ matrix.profile }}
  - run: cargo test --profile ${{ matrix.profile }}
```

### Publish to crates.io

```yaml
steps:
  - uses: actions/checkout@v5
  - run: cargo login ${{ secrets.CRATES_IO }}
  - run: cargo build -r
  - run: cargo package
  - run: cargo publish
```

## Ruby

### Setup and Cache

`ruby/setup-ruby` with `bundler-cache: true` auto-caches gems.

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: ruby/setup-ruby@ec02537da5712d66d4d50a0f33b7eb52773b5ed1
    with:
      ruby-version: '3.1'
      bundler-cache: true
  - run: bundle exec rake
```

### Matrix Build

```yaml
strategy:
  matrix:
    ruby-version: ['3.0', '3.1', '3.2']

steps:
  - uses: actions/checkout@v5
  - uses: ruby/setup-ruby@ec02537da5712d66d4d50a0f33b7eb52773b5ed1
    with:
      ruby-version: ${{ matrix.ruby-version }}
      bundler-cache: true
  - run: bundle exec rake
```

### Manual Cache (without bundler-cache)

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/cache@v4
    with:
      path: vendor/bundle
      key: ${{ runner.os }}-gems-${{ hashFiles('**/Gemfile.lock') }}
      restore-keys: |
        ${{ runner.os }}-gems-
  - run: |
      bundle config path vendor/bundle
      bundle install --jobs 4 --retry 3
  - run: bundle exec rake
```

### Linting with RuboCop

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: ruby/setup-ruby@ec02537da5712d66d4d50a0f33b7eb52773b5ed1
    with:
      ruby-version: '3.1'
      bundler-cache: true
  - run: bundle exec rubocop -f github
```

`-f github` outputs annotations in the PR Files changed tab.

### Publish to RubyGems

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: ruby/setup-ruby@ec02537da5712d66d4d50a0f33b7eb52773b5ed1
    with:
      ruby-version: '3.1'
      bundler-cache: true
  - name: Publish to RubyGems
    run: |
      mkdir -p $HOME/.gem
      touch $HOME/.gem/credentials
      chmod 0600 $HOME/.gem/credentials
      printf -- "---\n:rubygems_api_key: ${GEM_HOST_API_KEY}\n" > $HOME/.gem/credentials
      gem build *.gemspec
      gem push *.gem
    env:
      GEM_HOST_API_KEY: ${{ secrets.RUBYGEMS_AUTH_TOKEN }}
```

## .NET

### Setup and Cache

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-dotnet@v4
    with:
      dotnet-version: '8.0.x'
      cache: true
  - run: dotnet restore
  - run: dotnet build --no-restore
  - run: dotnet test --no-build
```

`cache: true` caches NuGet global-packages folder. Optionally set
`cache-dependency-path` for custom lock file locations.

### Matrix Build

```yaml
strategy:
  matrix:
    dotnet-version: ['6.0.x', '8.0.x']

steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-dotnet@v4
    with:
      dotnet-version: ${{ matrix.dotnet-version }}
      cache: true
  - run: dotnet restore
  - run: dotnet build --no-restore
  - run: dotnet test --no-build
```

### Publish to NuGet / GitHub Packages

```yaml
name: Upload dotnet package

on:
  release:
    types: [created]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      packages: write
      contents: read
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
          source-url: https://nuget.pkg.github.com/<owner>/index.json
        env:
          NUGET_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - run: dotnet build --configuration Release
      - run: dotnet pack --configuration Release
      - run: dotnet nuget push bin/Release/*.nupkg
```

## Swift

### Setup and Test

Swift is preinstalled on macOS runners. Use `swift-actions/setup-swift` for
specific versions or Ubuntu runners.

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: swift-actions/setup-swift@65540b95f51493d65f5e59e97dcef9629ddf11bf
    with:
      swift-version: "5.9"
  - run: swift build
  - run: swift test
```

### Matrix Build (OS + Version)

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest]
    swift: ["5.8", "5.9"]

runs-on: ${{ matrix.os }}
steps:
  - uses: swift-actions/setup-swift@65540b95f51493d65f5e59e97dcef9629ddf11bf
    with:
      swift-version: ${{ matrix.swift }}
  - uses: actions/checkout@v5
  - run: swift build
  - run: swift test
```

### Xcode Build (macOS)

For Xcode projects (not Swift Package Manager), use `xcodebuild` directly:

```yaml
runs-on: macos-latest
steps:
  - uses: actions/checkout@v5
  - run: xcodebuild -scheme MyScheme -destination 'platform=iOS Simulator,name=iPhone 15' test
```

To select a specific Xcode version:

```yaml
runs-on: macos-latest
steps:
  - uses: actions/checkout@v5
  - run: sudo xcode-select -s /Applications/Xcode_15.2.app
  - run: xcodebuild -scheme MyScheme test
```

## Quick Reference: Setup Actions

| Language | Setup Action | Cache Option | Lock File |
|----------|-------------|-------------|-----------|
| Node.js | `actions/setup-node@v4` | `cache: 'npm'/'yarn'/'pnpm'` | `package-lock.json` |
| Python | `actions/setup-python@v5` | `cache: 'pip'` | `requirements.txt` |
| Java | `actions/setup-java@v4` | `cache: maven/gradle` | `pom.xml` / `*.gradle` |
| Go | `actions/setup-go@v5` | Enabled by default | `go.sum` |
| Rust | (preinstalled) | `actions/cache@v4` manual | `Cargo.lock` |
| Ruby | `ruby/setup-ruby@SHA` | `bundler-cache: true` | `Gemfile.lock` |
| .NET | `actions/setup-dotnet@v4` | `cache: true` | `packages.lock.json` |
| Swift | `swift-actions/setup-swift@SHA` | No built-in | N/A |
