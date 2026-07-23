# High-density architecture

Use this mode when internal topology, repeated runtime structure, or storage state materially explains system behavior. It is especially effective for infrastructure regions, caches inside processes, queues and indexes inside storage, sharded systems, and paths crossing ownership boundaries.

Do not apply it automatically to sequences, small flows, or conceptual overviews. Dense visual language without dense information is ornament.

## Signature grammar

Combine several semantic layers on one canvas:

```text
╔══system / region════════════════════════╗
║ ┌─runtime─────────────────────────────┐ ║░
║ │ ┌─nested cache────────────────────┐ │ ║░
║ │ │■■■■■■■■■■····                   │ │ ║░
║ │ └─────────────────────────────────┘ │ ║░
║ └─────────────────────────────────────┘ ║░
╚═════════════════════════════════════════╝░
 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

┏━durable structure━━━━━━━━━━━━━━━━━━━━━━┓
┃■■■■■■■■■■■■■■■■◈◈◈◈                    ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

- Use double borders for major regions or focal external systems.
- Use single borders for processes, services, and ordinary components.
- Use heavy borders for queues, WALs, indexes, datasets, and other durable structures.
- Embed caches, buffers, shards, and internal stages inside the process or storage node that owns them.
- Use `░` shadows to separate major regions from the canvas, not every nested box.
- Use fill patterns only for real state: occupancy, indexed vs pending, hot vs cold, committed vs uncommitted.
- Align repeated instances so one shared ingress or egress route can branch cleanly.

## Boundary-crossing routes

Treat boundaries as part of the topology. Make lines cross them continuously and use the appropriate junction:

```text
╔══region════════════════════╗       ╔══external═════════╗
║ ┌────────┐                 ║░      ║ ┏━queue━━━━━━━━━┓ ║░
║ │ worker │─────────────────╬──────▶║ ┃■■■■■■■····    ┃ ║░
║ └────────┘                 ║░      ║ ┗━━━━━━━━━━━━━━━┛ ║░
╚════════════════════════════╝░      ╚═══════════════════╝░
 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░       ░░░░░░░░░░░░░░░░░░░░░
```

- Prefer `╠`, `╣`, `╬`, or a visible single-line crossing over stopping and restarting a route.
- Place gateways or load balancers on the boundary when they genuinely mediate traffic.
- Route shared trunks outside repeated nodes, then branch into aligned peers.
- Join repeated outputs before crossing into the next region when the destination sees one logical stream.

## Composition procedure

1. Draw major regions and the primary cross-region route.
2. Place gateways at boundary intersections when present.
3. Align repeated compute or service instances along one axis.
4. Expand only the internals that explain performance, durability, routing, or failure behavior.
5. Model persistent internals as nested heavy structures.
6. Add state textures and a legend only after geometry is stable.
7. Add one consistent shadow layer to major regions if it improves depth.
8. Remove empty space that does not separate semantic groups.

## Dense topology template

```text
                   ╔══runtime region════════════════╗
                   ║ ┌─worker─────────────────────┐ ║░
                   ║ │ ┌─memory cache───────────┐ │ ║░
╔══════════╗    ┌──╬▶│ │■■■■■■■■····            │ │ ╠──┐
║  client  ║───▶│GW║ │ └────────────────────────┘ │ ║░ │
╚══════════╝░   └──╬▶│ ┌─local cache────────────┐ │ ║░ │   ╔══storage region═════╗
 ░░░░░░░░░░░░      ║ │ │■■■■■■■■■■■■■■··        │ │ ║░ └──▶║ ┏━queue━━━━━━━━━━━┓ ║░
                   ║ │ └────────────────────────┘ │ ║░     ║ ┃■■■■■■■····      ┃ ║░
                   ║ └────────────────────────────┘ ║░     ║ ┗━━━━━━━━━━━━━━━━━┛ ║░
                   ║ ┌─worker──────────────────────┐║░     ║ ┏━dataset━━━━━━━━━┓ ║░
                   ║ │ [same meaningful internals] │╠─────▶║ ┃ [wal / index]   ┃ ║░
                   ║ └─────────────────────────────┘║░     ║ ┗━━━━━━━━━━━━━━━━━┛ ║░
                   ╚════════════════════════════════╝░     ╚═════════════════════╝░
                    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░      ░░░░░░░░░░░░░░░░░░░░░░░
```

Replace `[same meaningful internals]` with repeated detail only when comparison between instances matters. Otherwise show one expanded exemplar and keep peers compact.

## Compression rules

- Put shared context in the region label rather than every node.
- Expand one representative peer when all peers have identical internals.
- Use a textured bar instead of prose for quantity only when relative amount matters.
- Prefer nested compartments over edge labels that merely say “uses cache” or “writes WAL.”
- Keep the primary route visually straighter and darker than operational side paths.
- Split the diagram if two independent nested systems each demand their own legend or reading direction.

## Failure modes

- **Decorative shadows:** depth consumes ink but communicates no boundary.
- **Fake telemetry:** arbitrary fill bars imply measurements that do not exist.
- **Literal decomposition:** every code module becomes a box, obscuring runtime behavior.
- **Border soup:** several border weights appear without stable meanings.
- **Broken crossings:** routes stop at a region edge, making ownership transfer ambiguous.
- **Repeated verbosity:** identical internals are expanded in every peer despite no comparison.
