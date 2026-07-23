---
name: draw-text-diagrams
description: Create and refine compact terminal-friendly Unicode text diagrams and illustrations. Use for architecture and system diagrams, flows, lifecycles, sequences, boundaries, data layouts, comparisons, operational explanations, converting Mermaid into polished text, or improving existing ASCII/Unicode diagrams in Markdown, source files, terminals, and chat.
---

# Draw Text Diagrams

Turn structure into a coherent visual argument, not a decorated inventory. Optimize for information density while keeping one obvious reading path.

Read [references/visual-language.md](references/visual-language.md) before drawing. Read [references/templates.md](references/templates.md) when choosing a shape, composing nested structures, or starting from a blank canvas. Read [references/high-density-architecture.md](references/high-density-architecture.md) for architecture diagrams with regions, repeated runtimes, nested caches, queues, storage internals, or other layered operational detail.

## Workflow

### 1. Decide the message and canvas

State the one sentence the diagram must make obvious. Extract:

- entities, boundaries, and ownership
- relationships and their direction
- sequence, state, or data movement
- repeated structure and exceptional paths
- the detail that may be omitted

Choose the reading direction and approximate width before drawing:

- left to right for pipelines and transformations
- top to bottom for lifecycles, procedures, and deep nesting
- lanes for sequences and phases
- grids for comparisons and repeated peers
- center-out or nested frames for topology and ownership

Default to 80 columns for prose-adjacent diagrams and 100 columns for architecture diagrams. Exceed that only when splitting would obscure the idea.

### 2. Choose a construction method

Use the method that minimizes layout uncertainty.

#### Graph-first

Use for directed flows, dependency graphs, state transitions, and systems whose hard problem is topology.

1. Draft the smallest Mermaid graph that preserves all meaningful nodes, edges, labels, and subgraphs.
2. Choose Mermaid direction and subgraphs deliberately; do not accept the renderer's default layout as design intent.
3. Validate with the `mermaid` skill when available.
4. Render a text scaffold:

   ```bash
   ./scripts/render-mermaid.sh /path/to/diagram.mmd
   ```

5. Treat the output as geometry, not finished art. Recompose labels, containment, line routing, border weights, and whitespace using the visual language reference.

Switch to direct composition when Mermaid creates crossings, duplicates shared structure, flattens meaningful containment, or cannot express the spatial metaphor.

#### Direct composition

Use for nested systems, storage/data layouts, timelines, annotated ranges, repeated panels, comparisons, physical topology, or illustrations where spatial placement carries meaning.

1. Place the main anchors as short labels without borders.
2. Reserve rows and columns for the primary route.
3. Add branches and shared joins.
4. Wrap related anchors in labeled boundaries from the inside out.
5. Add border weight, texture, and secondary annotation last.

Do not ask the user to choose a method unless it changes the semantics. Perform intermediate construction privately unless the user asks to see it.

### 3. Compose complexity in layers

Build in this order:

1. **Geometry:** reading direction, alignment, spacing, containment.
2. **Semantics:** precise node and edge labels, ownership, start/end, cardinality.
3. **Hierarchy:** boundary weights, primary path, secondary paths, repeated peers.
4. **Compression:** collapse repeated labels, merge shared tails, move explanation outside the frame.
5. **Polish:** consistent corners, continuous connectors, balanced whitespace, optional texture.

Every added visual distinction must encode a distinction in the idea. Never use heavy borders, shadows, fill, or dashed lines merely to make the diagram look elaborate.

After the geometry works, run the compact-rendering pass in the visual language reference: solve nested areas as local canvases, promote repeated state to labeled bars or fills, trim non-semantic padding, and apply at most one semantic shadow layer.

For high-density architecture, make one additional pass after hierarchy: expose meaningful internals inside their owning nodes, align repeated peers, connect shared routes at the boundary, and use texture to show state or capacity. Keep sequence diagrams in the cleaner lane grammar unless nested state is itself the point.

### Style-first finalization gate

For any non-trivial system diagram, reject a technically correct draft that still looks like ordinary Mermaid boxes and arrows. Preserve sequence semantics when present, but place the lanes and state changes inside a composed system illustration rather than invoking a plain sequence-diagram exemption.

Before returning it:

1. Identify every applicable rendering opportunity: an owned subsystem can become a nested local canvas; a major region can take a one-cell shadow; a durable or ordered structure can become a labeled heavy bar; real state distinctions can become fills with a legend.
2. For a diagram with four or more entities, require at least three of these five techniques: nested canvases, semantic border hierarchy, one-cell region shadows, labeled heavy structures, and state fills with a legend. If fills would invent state, omit them and use the other four rather than lowering the visual bar.
3. Rebuild cramped or sparse sections instead of patching ornament onto weak geometry.
4. Trim padding only after the richer composition is stable.
5. Inspect the result as an illustration: it should show hierarchy, depth, and embedded state at first glance while preserving one continuous primary route.

### 4. Verify

Trace every path in the source model against the diagram. Confirm that:

- the intended first glance is obvious
- arrow direction and edge labels are unambiguous
- containment means ownership, scope, or physical location consistently
- parallel shapes mean comparable things
- no connector appears to terminate accidentally
- text does not touch borders
- alignment does not depend on tabs or trailing spaces
- the result remains legible as raw monospace text

For a standalone diagram file, run structural alignment checks:

```bash
node ./scripts/check-diagram.mjs /path/to/diagram.txt --strict-frames
```

For diagrams embedded in Markdown, lint every fenced `text` block without treating prose as diagram content:

```bash
node ./scripts/check-diagram.mjs /path/to/document.md --fenced-text --strict-frames
```

Use a fenced `text` block in Markdown. Preserve the surrounding document's terminology and update its history when repository instructions require it.

## Output discipline

Lead with the completed diagram or file change. Explain only non-obvious modeling choices and material omissions. If the requested diagram would imply a false guarantee, expose that distinction in the visual itself or in one short sentence beside it.
