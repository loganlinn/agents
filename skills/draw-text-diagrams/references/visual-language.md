# Visual language

## Contents

- Core principles
- Shape grammar
- Connectors
- Composition and layering
- High-leverage rendering techniques
- Density without clutter
- Terminal constraints
- Review checklist

## Core principles

### Make a claim

Give each diagram one dominant idea. A good diagram answers a question such as “where does authority live?”, “what happens next?”, or “what is shared?” If every fact has equal weight, the reader must reconstruct the model themselves.

### Assign meaning before style

Define a small visual vocabulary and use it consistently. Do not make two boxes different merely for variety. A border, texture, or connector style should mean something the reader can infer or learn from a short legend.

### Prefer visible structure over explanation

Use alignment for sequence, enclosure for scope, proximity for association, repeated geometry for peers, and whitespace for separation. Keep prose outside the diagram when geometry can express it.

## Shape grammar

Use these as defaults, then adapt to the document.

```text
┌─ordinary component──────┐   ╔══system / focal boundary══╗
│ concrete responsibility │   ║ owned or emphasized scope ║
└─────────────────────────┘   ╚═══════════════════════════╝

┏━durable or heavy structure━┓   ┌╌optional / conceptual╌┐
┃ queue, WAL, index, dataset ┃   ╎ future or conditional ╎
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛   └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

- Use single-line borders for ordinary nodes and local groupings.
- Use double-line borders for the outer system, a trust boundary, or at most one focal entity.
- Use heavy borders for durable structures only when durability matters to the story.
- Use dashed or dotted borders for optional, proposed, inferred, or logical elements.
- Put the group label into the top border when possible; avoid a separate title node.
- Nest no deeper than needed. Two meaningful levels usually outperform four literal levels.

Shadows can separate overlapping regions but are optional:

```text
┌────────────┐
│ component  │░
└────────────┘░
 ░░░░░░░░░░░░░░
```

Use one shadow direction and one layer. Never make shadows the dominant ink.

## Connectors

```text
A ─────────▶ B       directed transfer or dependency
A ◀────────▶ B       meaningful bidirectional exchange
A ────────── B       association without direction
A ╌╌╌╌╌╌╌╌▶ B       optional, eventual, or proposed path
      label           place a short verb on or beside the route

     ┌────────▶ B
A ───┤
     └────────▶ C     fan-out

B ───┐
     ├────────▶ D     fan-in
C ───┘
```

- Prefer arrowheads at the destination.
- Label edges with verbs when the relationship is not obvious.
- Route the primary path straight; make secondary paths bend around it.
- Cross a boundary visibly. Do not stop at the border and restart elsewhere.
- Avoid diagonal lines. Orthogonal routing makes intersections inspectable.
- Reserve `│`, `─`, `├`, `┬`, `┼`, and arrowheads for actual routes; decorative lines should not resemble connections.
- Use a legend only when two or more non-obvious encodings recur.

## Composition and layering

### Establish hierarchy

Use this visual order:

1. outer boundary or overall direction
2. primary path
3. participating components
4. secondary branches and annotations
5. texture or state details

The darkest or heaviest feature attracts the first glance. Spend that emphasis on the diagram's claim.

### Compose primitives

Build complex ideas by embedding simple grammars:

- Put a pipeline inside an ownership boundary.
- Put a queue or dataset inside a storage boundary.
- Put repeated peer nodes inside a region, then route one shared edge through the region boundary.
- Put a small range or progress illustration inside the component that owns it.
- Align multiple framed alternatives to make comparison implicit.
- Show a shared prefix once, then branch; show a shared tail once, then join.

Containment must mean one thing within a diagram: ownership, deployment, trust, physical location, or logical scope. If two kinds of containment are essential, distinguish their border styles and name both.

### Label at the highest useful level

Prefer:

```text
┌─Search workers────────────────────┐
│ ┌────────┐ ┌────────┐ ┌────────┐  │
│ │ worker │ │ worker │ │ worker │  │
│ └────────┘ └────────┘ └────────┘  │
└───────────────────────────────────┘
```

over repeating “search worker” inside every peer. Let the boundary carry shared context.

## High-leverage rendering techniques

Use these operations after the topology is correct. They add density and depth by encoding structure, state, or hierarchy—not by decorating empty space.

### Cast a one-cell shadow

Use `░` for ordinary depth and reserve `▒` for a stronger focal layer when the distinction matters. Offset the shadow exactly one cell down and right: append one cell to each visible right edge, then draw the bottom run one cell to the right of the left border.

```text
╔══region══════╗
║ ┌──────────┐ ║░
║ │ service  │ ║░
║ └──────────┘ ║░
╚══════════════╝░
 ░░░░░░░░░░░░░░░░
```

- Keep one shadow direction and one-cell stroke throughout the canvas.
- Shadow major regions or a focal object, not every nested box.
- Do not place shadow glyphs where they can look like routes or state fill.
- Do not mix `░` and `▒` casually. Assign them different depth levels or choose one.
- Let connectors cross the real border; never route along the shadow.

### Turn state into a labeled bar

Use a heavy box with its label in the top border for an ordered collection, occupancy, lifecycle range, queue, WAL, or dataset. The segments can express composition as well as scalar progress.

```text
┏━/wal━━━━━━━━━━━━━━━━━━┓
┃ ■■■■■■■■■■■◈◈◈◈       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━┛
```

- Keep one interior cell between fill and border.
- Use proportional lengths only for measured or explicitly approximate quantities.
- For qualitative state, show meaningful segment order and explain every recurring fill.
- Prefer a compact bar over prose such as “some committed, some pending” when position or proportion matters.
- Put the collection name in the border instead of spending a separate title row.

### Build a fill vocabulary and legend

Choose two to four visibly distinct fills. Their meanings are local to the diagram; define them nearby rather than assuming universal semantics.

```text
┌──────┐ ┌──────┐ ┌──────┐
│██████│ │▞▞▞▞▞▞│ │░░░░░░│
│██████│ │▞▞▞▞▞▞│ │░░░░░░│
└──────┘ └──────┘ └──────┘
 01.bin   02.bin ▲ 03.bin
                 │
             commit point

█ indexed   ▞ committed, unindexed   ░ written, uncommitted
```

- Use fill inside repeated cells, ranges, or collections—not behind prose labels.
- Align a cursor or commit marker with the exact column or item it denotes.
- Keep the legend in the diagram's reading order and as close as practical to the marks.
- `█` reads as dense or complete, `▞` as intermediate or hatched, `░` as light or pending, and `◈` as a transition marker; these are useful defaults, not fixed meanings.
- Avoid using `░` for both shadow and state in one diagram unless enclosure makes the two roles unmistakable. Otherwise change one glyph.

### Trim the canvas after composition

Do a dedicated compression pass; do not merely choose narrow boxes at the start.

1. Remove blank first and last rows and non-semantic outer columns.
2. Put group labels in borders and shared labels at the highest containing level.
3. Collapse blank rows between closely related peers.
4. Shorten labels before bending the primary route.
5. Let a shared trunk cross a boundary once, then branch locally.
6. Reduce ordinary region padding toward one column and zero or one row, while preserving one cell between text and borders.
7. Delete wrapper boxes that add neither ownership nor grouping.

Compactness is not zero whitespace. Preserve gaps that separate unrelated groups, disambiguate crossings, or reveal hierarchy.

### Compose recursively with local canvases

Treat a complex region as its own coordinate system. Solve it inside-out, then use the completed region as one object in the parent diagram.

1. Draw the smallest meaningful inner structure.
2. Stabilize its width and internal routes.
3. Wrap it in the boundary that owns it.
4. Expose named ingress, egress, or junction ports on that boundary.
5. Place and route the wrapped object in the parent canvas.

```text
╔═namespace═══════════════════════╗
║ ┏━/wal (shared)━━━━━━━━━━━━━━┓  ║░
║ ┃ ■■■■■■■■■■■■■■◈◈◈          ┃  ║░
║ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛  ║░
║       │ hash(id) % shards       ║░
║       ├────────┬────────┐       ║░
║       ▼        ▼        ▼       ║░
║ ┌────────┐ ┌────────┐ ┌────────┐║░
║ │shard 0 │ │shard 1 │ │shard N │║░
║ └────────┘ └────────┘ └────────┘║░
╚═════════════════════════════════╝░
 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

Use two or three meaningful nesting levels. Label internals locally and relationships between regions in the parent. A route crossing the wrapper must remain continuous through a visible boundary junction; do not stop and restart it on either side.

## Density without clutter

- Shorten nouns only after terminology is established.
- Prefer one concrete responsibility per node over lists of implementation details.
- Combine edge labels with phase labels when they describe the same transition.
- Align peers to share visual axes.
- Use whitespace around groups, not between every related item.
- Remove boxes whose only purpose is to hold one label.
- Remove abstract peers that do not correspond to a real artifact, boundary, state, or decision.
- Split a diagram when it has two unrelated reading directions or two equally dominant claims.
- Keep useful asymmetry. A small exceptional branch should look smaller than the main path.

Do not compress by deleting the distinction the diagram exists to explain. A compact false model is worse than a wider accurate one.

## Texture and state

Use texture to encode quantity or lifecycle only when the pattern is explained:

```text
████ committed      ▞▞▞▞ pending index      ░░░░ uncommitted
■■■■■■■······ queue occupancy               ✓ complete   ! failed
```

Avoid emoji and ambiguous-width glyphs when strict alignment matters. Symbols such as `✓` may render differently across terminals; use short words when portability is more important than compactness.

## Terminal constraints

- Assume a monospace font but not a specific terminal emulator.
- Prefer Unicode box-drawing characters; provide pure ASCII only when requested or required by the target.
- Keep Markdown diagrams in fenced `text` blocks.
- Never use tabs. Never depend on trailing spaces.
- Keep labels away from borders by at least one cell.
- Prefer 80 columns; treat 100 as the normal architecture ceiling.
- Avoid color as the only carrier of meaning.
- Inspect raw source, not only a rendered Markdown preview.
- If alignment is critical across unknown terminals, avoid emoji, combining marks, and East Asian ambiguous-width characters.

## Review checklist

Ask in order:

1. What does the eye see first, and is that the intended claim?
2. Can a reader find the start and follow the primary path without prose?
3. Does each boundary have a single consistent meaning?
4. Can every arrow be spoken as “source verb destination”?
5. Are repeated shapes true peers?
6. Is any visual weight decorative rather than semantic?
7. Can one node, label, border, or route be removed without losing meaning?
8. Does the raw text remain aligned at the target width?
