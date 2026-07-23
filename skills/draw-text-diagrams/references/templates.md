# Templates and archetypes

Copy geometry, then replace placeholders and resize deliberately. Templates are starting constraints, not forms to fill mechanically.

## Contents

- Primitives
- Flows and lifecycles
- Branches and joins
- Boundaries and nesting
- Sequences and lanes
- Data layouts and ranges
- Comparisons
- Composed archetypes

## Primitives

### Node

```text
┌─[name]──────────────┐
│ [responsibility]    │
└─────────────────────┘
```

### Labeled boundary

```text
╔══[system / region / owner]═════════════╗
║                                        ║
║  [contained structure]                 ║
║                                        ║
╚════════════════════════════════════════╝
```

### Nested boundary

```text
╔══[outer scope]═══════════════════════════════╗
║ ┌─[inner scope]────────────────────────────┐ ║
║ │ ┌──────────┐       ┌──────────┐          │ ║
║ │ │ [node A] │──────▶│ [node B] │          │ ║
║ │ └──────────┘       └──────────┘          │ ║
║ └──────────────────────────────────────────┘ ║
╚══════════════════════════════════════════════╝
```

## Flows and lifecycles

### Horizontal pipeline

```text
┌─────────┐  [verb]  ┌─────────┐  [verb]  ┌─────────┐
│ [input] │─────────▶│ [stage] │─────────▶│[output] │
└─────────┘          └─────────┘          └─────────┘
```

### Vertical lifecycle

```text
┌───────────┐
│ [STATE 1] │
└─────┬─────┘
      │ [transition]
      ▼
┌───────────┐
│ [STATE 2] │
└─────┬─────┘
      │ [transition]
      ▼
┌───────────┐
│ [STATE 3] │
└───────────┘
```

### Feedback loop

```text
┌─────────┐  [forward]  ┌─────────┐
│ [state] │────────────▶│ [state] │
└────▲────┘             └────┬────┘
     └──────[feedback]───────┘
```

## Branches and joins

### Fan-out

```text
                  ┌──────────┐
             ┌───▶│ [path A] │
┌─────────┐  │    └──────────┘
│ [source]│──┤    ┌──────────┐
└─────────┘  └───▶│ [path B] │
                  └──────────┘
```

### Fan-in with shared tail

```text
┌──────────┐
│ [path A] │───┐
└──────────┘   │    ┌──────────┐
               ├───▶│ [shared] │
┌──────────┐   │    └──────────┘
│ [path B] │───┘
└──────────┘
```

### Parallel continuation chains

```text
┌─[scope A]────────────────────────────────────┐
│ [page 1] ──[cursor]──▶ [page 2] ──────────▶ ✓│
└──────────────────────────────────────────────┘
┌─[scope B]────────────────────────┐
│ [page 1] ────────[cursor]─────▶ ✓│
└──────────────────────────────────┘
```

## Boundaries and nesting

### System and external dependency

```text
╔══[owned system]═══════════════════════════════╗
║ ┌──────────┐  [message]  ┌──────────┐         ║
║ │ [source] │────────────▶│ [worker] │─────┐   ║
║ └──────────┘             └──────────┘     │   ║
╚═══════════════════════════════════════════│═══╝
                                            │ [write]
                                            ▼
                                      ╔══════════╗
                                      ║[external]║
                                      ╚══════════╝
```

### Two trust or deployment regions

```text
┌─[region A]──────────────────┐       ┌─[region B]──────────────────┐
│ ┌────────┐    ┌─────────┐   │       │   ┌─────────┐    ┌────────┐ │
│ │[client]│───▶│[gateway]│───┼──────▶│   │[service]│───▶│[store] │ │
│ └────────┘    └─────────┘   │ [link]│   └─────────┘    └────────┘ │
└─────────────────────────────┘       └─────────────────────────────┘
```

## Sequences and lanes

### Compact sequence

```text
┌────────┐      ┌────────┐      ┌────────┐
│ [A]    │      │ [B]    │      │ [C]    │
└───┬────┘      └───┬────┘      └───┬────┘
    │ [request]      │               │
    ├───────────────▶│               │
    │                │ [write]       │
    │                ├──────────────▶│
    │                │ [accepted]    │
    │                │◀──────────────┤
    │ [result]       │               │
    │◀───────────────┤               │
```

### Phase lanes

```text
  ┌──────────────┐  ┊  ┌──────────────────┐  ┊  ┌──────────────┐
  │ [phase 1]    │  ┊  │ [phase 2]        │  ┊  │ [phase 3]    │
  │ [artifact]   │  ┊  │ [artifact]       │  ┊  │ [artifact]   │
  └──────────────┘  ┊  └──────────────────┘  ┊  └──────────────┘
  ──────────────────────────────────────────────────────────────▶
       [time / request / maturity / ownership progression]
```

## Data layouts and ranges

### Ordered range with cursor and bound

```text
┌─[ordered index]───────────────────────────────────────────────┐
│ ┌─page 1─────────────┐  ┌─page 2─────────────┐   [excluded]   │
│ │ [k1] [k2] [k3]     │  │ [k4] [k5] [k6]     │   [k >= bound] │
│ └────────────────────┘  └────────────────────┘                │
│            ▲                       ▲                 ▲        │
│         cursor 1                cursor 2            bound     │
└───────────────────────────────────────────────────────────────┘
```

### Layered storage

```text
┏━[dataset / namespace]━━━━━━━━━━━━━━━━━━━┓
┃ ┏━[append log]━━━━━━━━━━━━━━━━━━━━━━━━┓ ┃
┃ ┃■■■■■■■■■■■■■■■····                  ┃ ┃
┃ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ┃
┃                │ [partition / index]    ┃
┃          ┌─────┼──────────┐             ┃
┃          ▼     ▼          ▼             ┃
┃      ┌──────┐ ┌──────┐ ┌──────┐         ┃
┃      │[part]│ │[part]│ │[part]│         ┃
┃      └──────┘ └──────┘ └──────┘         ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

## Comparisons

### Alternatives

```text
┌─[option A]───────────────┐   ┌─[option B]───────────────┐
│ [shared dimension]       │   │ [shared dimension]       │
│ [distinct consequence]   │   │ [distinct consequence]   │
└──────────────────────────┘   └──────────────────────────┘
            ▲                               ▲
            └────── [decision criterion] ───┘
```

### Before and after

```text
        CURRENT                              TARGET
┌──────────────────────┐            ┌──────────────────────┐
│ [existing path]      │──[change]─▶│ [desired path]       │
│ [current constraint] │            │ [new invariant]      │
└──────────────────────┘            └──────────────────────┘
```

## Composed archetypes

### Durable work pipeline inside an owned environment

```text
╔══Application environment════════════════════════════════════════════╗
║ ┌─API────────────┐  identity only ┏━Durable queue━━━━┓              ║
║ │ commits change │───────────────▶┃ event · cursor   ┃──────┐       ║
║ └────────────────┘                ┗━━━━━━━━━━━━━━━━━━┛      ▼       ║
║                                                     ┌─Worker──────┐ ║
║                                   ┌─Run state────┐  │ load latest │ ║
║                                   │counts·errors │◀▶│ transform   │ ║
║                                   └──────────────┘  └──────┬──────┘ ║
╚════════════════════════════════════════════════════════════│════════╝
                                                             │ upsert
                                                             ▼
                                                       ╔════════════╗
                                                       ║Search store║
                                                       ╚════════════╝
```

### Bounded scan: membership first, current content second

```text
                 capture bound = T4
                         │
                         ▼
┌─ordered rows────────────────────────────────────────────────┐
│ [T1,id1] [T2,id2] │ [T2,id3] [T3,id4] │ [T5,id5 excluded]   │
│       page 1       ▲       page 2       ▲          ▲        │
│                    cursor 1             cursor 2   bound    │
└─────────────────────────┬───────────────────────────────────┘
                          │ IDs only
                          ▼
               ┌─authoritative load─────┐
               │ current eligibility    │
               │ current content        │
               └───────────┬────────────┘
                           ▼
                    transform + write
```

This archetype deliberately separates a stable membership bound from content snapshot semantics.
