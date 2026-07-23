#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <diagram.mmd>" >&2
  exit 2
fi

input=$1
if [[ ! -f $input ]]; then
  echo "Error: file not found: $input" >&2
  exit 1
fi

export npm_config_cache="${npm_config_cache:-${TMPDIR:-/tmp}/draw-text-diagrams-npm-cache}"

MERMAID_INPUT=$input npx -y --package beautiful-mermaid node -e '
const fs = require("node:fs")
const path = require("node:path")
const binPath = process.env.PATH.split(":")[0]
const moduleRoot = path.dirname(binPath)
const { renderMermaidAscii } = require(path.join(moduleRoot, "beautiful-mermaid"))
const source = fs.readFileSync(process.env.MERMAID_INPUT, "utf8")
process.stdout.write(renderMermaidAscii(source))
process.stdout.write("\n")
'
