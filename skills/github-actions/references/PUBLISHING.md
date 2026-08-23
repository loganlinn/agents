# Publishing Packages and Images

## npm: Public Registry

Requires `NPM_TOKEN` secret (generate at npmjs.com > Access Tokens).

```yaml
name: Publish to npm
on:
  release:
    types: [published]
jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v4
        with:
          node-version: '20.x'
          registry-url: 'https://registry.npmjs.org'
      - run: npm ci
      - run: npm publish --provenance --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

`--provenance` generates a verifiable build attestation (requires `id-token: write`).
`--access public` is required for scoped packages (`@scope/pkg`).

## npm: GitHub Packages

Uses `GITHUB_TOKEN` -- no extra secrets needed.

```yaml
name: Publish to GitHub Packages
on:
  release:
    types: [published]
jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v4
        with:
          node-version: '20.x'
          registry-url: 'https://npm.pkg.github.com'
          scope: '@your-org'
      - run: npm ci
      - run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

The `scope` input must match your GitHub org/user. The package `name` in
`package.json` must use the same scope: `"name": "@your-org/my-package"`.

## npm: Both Registries in One Workflow

`setup-node` rewrites `.npmrc` on each call, so invoke it twice:

```yaml
name: Publish to npm + GitHub Packages
on:
  release:
    types: [published]
jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
    steps:
      - uses: actions/checkout@v5

      - uses: actions/setup-node@v4
        with:
          node-version: '20.x'
          registry-url: 'https://registry.npmjs.org'
      - run: npm ci
      - run: npm publish --provenance --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}

      - uses: actions/setup-node@v4
        with:
          node-version: '20.x'
          registry-url: 'https://npm.pkg.github.com'
          scope: '@your-org'
      - run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## PyPI: Trusted Publishing with OIDC

No stored API tokens. Configure a "trusted publisher" on pypi.org linking your
GitHub org, repo, workflow filename, and (optionally) environment name.

```yaml
name: Publish to PyPI
on:
  release:
    types: [published]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-python@v5
        with:
          python-version: '3.x'
      - name: Build distributions
        run: |
          python -m pip install build
          python -m build
      - uses: actions/upload-artifact@v4
        with:
          name: release-dists
          path: dist/

  publish:
    runs-on: ubuntu-latest
    needs: build
    permissions:
      id-token: write
    environment: release
    steps:
      - uses: actions/download-artifact@v5
        with:
          name: release-dists
          path: dist/
      - uses: pypa/gh-action-pypi-publish@release/v1
```

Key details:
- The `id-token: write` permission lets the action exchange an OIDC token for
  a short-lived PyPI API token.
- Omit `username` and `password` -- the action detects trusted publishing
  automatically.
- Using an `environment` (e.g., `release`) allows adding deployment protection
  rules and is recommended by PyPI for the OIDC trust configuration.
- The build and publish jobs are separate so the publish job has minimal
  permissions.

## Docker: Docker Hub

Requires secrets `DOCKER_USERNAME` and `DOCKER_PASSWORD`.

```yaml
name: Publish Docker image to Docker Hub
on:
  release:
    types: [published]
jobs:
  push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      attestations: write
      id-token: write
    steps:
      - uses: actions/checkout@v5

      - uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: my-namespace/my-repo

      - id: push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

      - uses: actions/attest-build-provenance@v3
        with:
          subject-name: index.docker.io/my-namespace/my-repo
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true
```

## Docker: GitHub Container Registry (GHCR)

Uses `GITHUB_TOKEN` -- no extra secrets.

```yaml
name: Publish Docker image to GHCR
on:
  push:
    tags: ['v*']
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
jobs:
  push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      attestations: write
      id-token: write
    steps:
      - uses: actions/checkout@v5

      - uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}

      - id: push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

      - uses: actions/attest-build-provenance@v3
        with:
          subject-name: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true
```

## Docker: Both Registries

Log in to both registries, list both image names in `metadata-action`, and
push once:

```yaml
name: Publish Docker image
on:
  release:
    types: [published]
jobs:
  push:
    runs-on: ubuntu-latest
    permissions:
      packages: write
      contents: read
    steps:
      - uses: actions/checkout@v5

      - uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: |
            my-namespace/my-repo
            ghcr.io/${{ github.repository }}

      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

## Docker: Multi-Platform Builds

Use QEMU and Docker Buildx to build for multiple architectures:

```yaml
name: Multi-platform Docker image
on:
  release:
    types: [published]
jobs:
  push:
    runs-on: ubuntu-latest
    permissions:
      packages: write
      contents: read
    steps:
      - uses: actions/checkout@v5

      - uses: docker/setup-qemu-action@v3

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}

      - uses: docker/build-push-action@v6
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

The `platforms` field accepts a comma-separated list. Common values:
`linux/amd64`, `linux/arm64`, `linux/arm/v7`.

## Maven: GitHub Packages

`pom.xml` must declare a distribution repository with `id` `github`:

```xml
<distributionManagement>
  <repository>
    <id>github</id>
    <name>GitHub Packages</name>
    <url>https://maven.pkg.github.com/OWNER/REPO</url>
  </repository>
</distributionManagement>
```

```yaml
name: Publish Maven package to GitHub Packages
on:
  release:
    types: [created]
jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - run: mvn --batch-mode deploy
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

`setup-java` auto-generates `~/.m2/settings.xml` with `GITHUB_TOKEN` auth
for the `github` server id.

## Maven: Central Repository (OSSRH)

`pom.xml` must declare:

```xml
<distributionManagement>
  <repository>
    <id>ossrh</id>
    <name>Central Repository OSSRH</name>
    <url>https://oss.sonatype.org/service/local/staging/deploy/maven2/</url>
  </repository>
</distributionManagement>
```

```yaml
name: Publish Maven package to Maven Central
on:
  release:
    types: [created]
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          server-id: ossrh
          server-username: MAVEN_USERNAME
          server-password: MAVEN_PASSWORD
      - run: mvn --batch-mode deploy
        env:
          MAVEN_USERNAME: ${{ secrets.OSSRH_USERNAME }}
          MAVEN_PASSWORD: ${{ secrets.OSSRH_TOKEN }}
```

`server-id` must match the `<id>` in `pom.xml`. `server-username` and
`server-password` name the env vars that `setup-java` writes into
`settings.xml`.

## Maven: Both Central and GitHub Packages

Call `setup-java` twice -- it rewrites `settings.xml` each time:

```yaml
name: Publish to Maven Central + GitHub Packages
on:
  release:
    types: [created]
jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v5

      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          server-id: ossrh
          server-username: MAVEN_USERNAME
          server-password: MAVEN_PASSWORD
      - run: mvn --batch-mode deploy
        env:
          MAVEN_USERNAME: ${{ secrets.OSSRH_USERNAME }}
          MAVEN_PASSWORD: ${{ secrets.OSSRH_TOKEN }}

      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - run: mvn --batch-mode deploy
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Gradle: GitHub Packages

`build.gradle` must configure the publishing repository:

```groovy
plugins {
    id 'maven-publish'
}

publishing {
    repositories {
        maven {
            name = "GitHubPackages"
            url = "https://maven.pkg.github.com/OWNER/REPO"
            credentials {
                username = System.getenv("GITHUB_ACTOR")
                password = System.getenv("GITHUB_TOKEN")
            }
        }
    }
}
```

```yaml
name: Publish Gradle package to GitHub Packages
on:
  release:
    types: [created]
jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew publish
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Gradle: Maven Central (OSSRH)

`build.gradle` must configure the OSSRH repository:

```groovy
plugins {
    id 'maven-publish'
}

publishing {
    repositories {
        maven {
            name = "OSSRH"
            url = "https://oss.sonatype.org/service/local/staging/deploy/maven2/"
            credentials {
                username = System.getenv("MAVEN_USERNAME")
                password = System.getenv("MAVEN_PASSWORD")
            }
        }
    }
}
```

```yaml
name: Publish Gradle package to Maven Central
on:
  release:
    types: [created]
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew publish
        env:
          MAVEN_USERNAME: ${{ secrets.OSSRH_USERNAME }}
          MAVEN_PASSWORD: ${{ secrets.OSSRH_TOKEN }}
```

## GitHub Releases: Create on Tag Push

```yaml
name: Create GitHub Release
on:
  push:
    tags: ['v*']
permissions:
  contents: write
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Create release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: gh release create "${{ github.ref_name }}" --generate-notes
```

To attach build artifacts:

```yaml
      - name: Build
        run: make build

      - name: Create release with assets
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release create "${{ github.ref_name }}" \
            --generate-notes \
            dist/*.tar.gz dist/*.zip
```

`--generate-notes` auto-generates release notes from merged PRs and commits
since the previous tag.

## Metadata Action Tag Patterns

`docker/metadata-action` generates tags from git context. Common configurations:

```yaml
- uses: docker/metadata-action@v5
  with:
    images: ghcr.io/${{ github.repository }}
    tags: |
      type=semver,pattern={{version}}
      type=semver,pattern={{major}}.{{minor}}
      type=semver,pattern={{major}}
      type=sha
```

Given tag `v1.2.3`, this produces: `1.2.3`, `1.2`, `1`, and the short SHA.

## Quick Reference: Secrets and Permissions

| Registry | Auth Method | Secrets Needed | Permissions |
|---|---|---|---|
| npm (npmjs.org) | Token | `NPM_TOKEN` | `id-token: write` (for provenance) |
| npm (GitHub Packages) | GITHUB_TOKEN | none | `packages: write` |
| PyPI | OIDC trusted publishing | none | `id-token: write` |
| Docker Hub | Username/password | `DOCKER_USERNAME`, `DOCKER_PASSWORD` | `contents: read` |
| GHCR | GITHUB_TOKEN | none | `packages: write` |
| Maven Central (OSSRH) | Username/token | `OSSRH_USERNAME`, `OSSRH_TOKEN` | none |
| Maven (GitHub Packages) | GITHUB_TOKEN | none | `packages: write` |
| GitHub Releases | GITHUB_TOKEN | none | `contents: write` |
