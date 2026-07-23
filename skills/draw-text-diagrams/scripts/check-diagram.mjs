#!/usr/bin/env node

import fs from 'node:fs'

function usage() {
  console.error(
    'Usage: check-diagram.mjs <file> [--max-width <columns>] [--fenced-text] [--strict-frames]',
  )
}

const args = process.argv.slice(2)
if (args.length === 0) {
  usage()
  process.exit(2)
}

const input = args[0]
let maxWidth = 100
let fencedText = false
let strictFrames = false
for (let i = 1; i < args.length; i += 1) {
  if (args[i] === '--fenced-text') {
    fencedText = true
    continue
  }
  if (args[i] === '--strict-frames') {
    strictFrames = true
    continue
  }
  if (args[i] === '--max-width' && args[i + 1] !== undefined) {
    maxWidth = Number(args[i + 1])
    i += 1
    continue
  }
  usage()
  process.exit(2)
}

if (!Number.isInteger(maxWidth) || maxWidth < 20) {
  console.error('Error: --max-width must be an integer of at least 20')
  process.exit(2)
}

function isCombining(codePoint) {
  return (
    (codePoint >= 0x0300 && codePoint <= 0x036f) ||
    (codePoint >= 0x1ab0 && codePoint <= 0x1aff) ||
    (codePoint >= 0x1dc0 && codePoint <= 0x1dff) ||
    (codePoint >= 0x20d0 && codePoint <= 0x20ff) ||
    (codePoint >= 0xfe20 && codePoint <= 0xfe2f)
  )
}

function isWide(codePoint) {
  return (
    codePoint >= 0x1100 &&
    (codePoint <= 0x115f ||
      codePoint === 0x2329 ||
      codePoint === 0x232a ||
      (codePoint >= 0x2e80 && codePoint <= 0xa4cf && codePoint !== 0x303f) ||
      (codePoint >= 0xac00 && codePoint <= 0xd7a3) ||
      (codePoint >= 0xf900 && codePoint <= 0xfaff) ||
      (codePoint >= 0xfe10 && codePoint <= 0xfe19) ||
      (codePoint >= 0xfe30 && codePoint <= 0xfe6f) ||
      (codePoint >= 0xff00 && codePoint <= 0xff60) ||
      (codePoint >= 0xffe0 && codePoint <= 0xffe6) ||
      (codePoint >= 0x1f300 && codePoint <= 0x1faff) ||
      (codePoint >= 0x20000 && codePoint <= 0x3fffd))
  )
}

function displayWidth(line) {
  let width = 0
  for (const character of line) {
    const codePoint = character.codePointAt(0)
    if (codePoint === 0xfe0f || isCombining(codePoint)) continue
    width += isWide(codePoint) ? 2 : 1
  }
  return width
}

function displayCells(line) {
  const cells = []
  for (const character of line) {
    const codePoint = character.codePointAt(0)
    if (codePoint === 0xfe0f || isCombining(codePoint)) continue
    cells.push(character)
    if (isWide(codePoint)) cells.push(undefined)
  }
  return cells
}

const frameFamilies = {
  '┌': { topRight: '┐', bottomLeft: '└', bottomRight: '┘', vertical: '│' },
  '╔': { topRight: '╗', bottomLeft: '╚', bottomRight: '╝', vertical: '║' },
  '┏': { topRight: '┓', bottomLeft: '┗', bottomRight: '┛', vertical: '┃' },
}

const boundaryJunctions = new Set('├┤┬┴┼╠╣╦╩╬┣┫┳┻╋╪╫')
const bottomCrossings = new Set('─━═╌│┃║┼╬╪╫┴┻╩┬┳╦▲▼◀▶')
const shadowGlyphs = new Set('░▒')

function extractDiagrams(sourceLines, problems) {
  if (!fencedText) {
    return [{ lines: sourceLines.map((text, index) => ({ text, lineNumber: index + 1 })) }]
  }

  const diagrams = []
  let active
  for (const [index, text] of sourceLines.entries()) {
    if (!active && /^```text\s*$/.test(text)) {
      active = { lines: [] }
      continue
    }
    if (active && /^```\s*$/.test(text)) {
      diagrams.push(active)
      active = undefined
      continue
    }
    if (active) active.lines.push({ text, lineNumber: index + 1 })
  }
  if (active) problems.push('unterminated fenced text block')
  if (diagrams.length === 0) problems.push('no fenced text blocks found')
  return diagrams
}

function checkFrameGeometry(diagram, problems) {
  const rows = diagram.lines.map(({ text }) => displayCells(text))

  for (const [rowIndex, cells] of rows.entries()) {
    for (let left = 0; left < cells.length; left += 1) {
      const family = frameFamilies[cells[left]]
      if (!family) continue

      const right = cells.indexOf(family.topRight, left + 1)
      if (right === -1) continue

      const topInterior = cells.slice(left + 1, right)
      if (topInterior.some((glyph) => '▲▼◀▶'.includes(glyph))) continue
      const verticals = new Set(
        cells.slice(left + 1, right).includes('╌') ? [family.vertical, '╎'] : [family.vertical],
      )

      const nextRow = rows[rowIndex + 1]
      const continuesAt = (column) => {
        const glyph = nextRow?.[column]
        return verticals.has(glyph) || boundaryJunctions.has(glyph)
      }
      if (!continuesAt(left) && !continuesAt(right)) continue

      let bottom = -1
      for (let candidate = rowIndex + 1; candidate < rows.length; candidate += 1) {
        if (
          rows[candidate][left] === family.bottomLeft &&
          rows[candidate][right] === family.bottomRight
        ) {
          bottom = candidate
          break
        }
      }

      const topLine = diagram.lines[rowIndex].lineNumber
      if (bottom === -1) {
        problems.push(
          `${topLine}:${left + 1}: frame has no matching ${family.bottomLeft}…${family.bottomRight} at the same columns`,
        )
        continue
      }

      for (let row = rowIndex + 1; row < bottom; row += 1) {
        for (const column of [left, right]) {
          const glyph = rows[row][column]
          if (!verticals.has(glyph) && !boundaryJunctions.has(glyph)) {
            problems.push(
              `${diagram.lines[row].lineNumber}:${column + 1}: expected ${[...verticals].join('/')} or a boundary junction`,
            )
          }
        }
      }

      for (let column = left + 1; column < right; column += 1) {
        const glyph = rows[bottom][column]
        if (!bottomCrossings.has(glyph)) {
          problems.push(
            `${diagram.lines[bottom].lineNumber}:${column + 1}: broken bottom border`,
          )
          break
        }
      }

      const shadow = rows[bottom][right + 1]
      if (shadowGlyphs.has(shadow)) {
        const floor = rows[bottom + 1]
        const validFloor =
          floor &&
          Array.from({ length: right - left + 1 }, (_, offset) => left + 1 + offset).every(
            (column) => floor[column] === shadow,
          )
        if (!validFloor) {
          problems.push(
            `${diagram.lines[bottom].lineNumber}:${right + 2}: ${shadow} shadow needs a one-cell down-right floor`,
          )
        }
      }
    }
  }
}

let source
try {
  source = fs.readFileSync(input, 'utf8')
} catch (error) {
  console.error(`Error: ${error.message}`)
  process.exit(1)
}

const problems = []
const lines = source.replace(/\r\n/g, '\n').split('\n')
const diagrams = extractDiagrams(lines, problems)
for (const diagram of diagrams) {
  for (const { text: line, lineNumber } of diagram.lines) {
    if (line.includes('\t')) problems.push(`${lineNumber}: contains a tab`)
    if (/\s+$/.test(line)) problems.push(`${lineNumber}: has trailing whitespace`)
    const width = displayWidth(line)
    if (width > maxWidth) {
      problems.push(`${lineNumber}: width ${width} exceeds ${maxWidth}`)
    }
  }
  if (strictFrames) checkFrameGeometry(diagram, problems)
}

if (problems.length > 0) {
  console.error(problems.join('\n'))
  process.exit(1)
}

const diagramLines = diagrams.flatMap(({ lines: blockLines }) => blockLines)
const widest = Math.max(0, ...diagramLines.map(({ text }) => displayWidth(text)))
console.log(
  `OK: ${diagramLines.length} diagram lines in ${diagrams.length} block(s), widest ${widest}/${maxWidth} columns`,
)
