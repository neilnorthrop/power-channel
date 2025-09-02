# Feature Flags – Visual Diagrams

These Mermaid diagrams visualize the two schema options and key flows from `feature_flag_spike`.

## Schema – Simple (per-model `flag_id`)

PNG: docs/feature_flags/diagrams/schema_simple.png

```mermaid
erDiagram
  USER ||--o{ USER_FLAG : "has"
  FLAG ||--o{ USER_FLAG : "granted for user"
  FLAG ||--o{ FLAG_REQUIREMENT : "has requirements"

  USER {
    bigint id PK
    ...
  }

  FLAG {
    bigint id PK
    string name
    string slug UNIQUE
    text description
  }

  USER_FLAG {
    bigint id PK
    bigint user_id FK
    bigint flag_id FK
    UNIQUE user_id, flag_id
  }

  FLAG_REQUIREMENT {
    bigint id PK
    bigint flag_id FK
    string requirement_type  "Resource|Item|Building|Flag|Skill"
    bigint requirement_id
    integer quantity
  }

  %% Unlockables each get an optional flag_id
  ACTION {
    bigint id PK
    string name
    bigint flag_id FK "nullable gate"
  }

  ITEM {
    bigint id PK
    string name
    bigint flag_id FK "nullable gate"
  }

  SKILL {
    bigint id PK
    string name
    bigint flag_id FK "nullable gate"
  }

  BUILDING {
    bigint id PK
    string name
    bigint flag_id FK "nullable gate"
  }

  RECIPE {
    bigint id PK
    string name
    bigint flag_id FK "nullable gate"
  }
```

## Schema – Flexible (polymorphic `unlockables` join)

PNG: docs/feature_flags/diagrams/schema_flexible.png

```mermaid
erDiagram
  USER ||--o{ USER_FLAG : "has"
  FLAG ||--o{ USER_FLAG : "granted for user"
  FLAG ||--o{ FLAG_REQUIREMENT : "has requirements"
  FLAG ||--o{ UNLOCKABLE : "gates"

  UNLOCKABLE {
    bigint id PK
    bigint flag_id FK
    string unlockable_type "Action|Item|Skill|Building|Recipe"
    bigint unlockable_id
    UNIQUE flag_id, unlockable_type, unlockable_id
  }

  %% Domain models stay clean (no flag_id column needed)
  ACTION {
    bigint id PK
    string name
  }
  ITEM { bigint id PK }
  SKILL { bigint id PK }
  BUILDING { bigint id PK }
  RECIPE { bigint id PK }
```

## Flow – Award flags on craft/build

PNG: docs/feature_flags/diagrams/flow_award_sequence.png

```mermaid
sequenceDiagram
  participant U as User
  participant C as Controller
  participant S as Service
  participant F as FlagEngine
  participant DB as DB

  U->>C: POST /api/v1/crafting (recipe)
  C->>S: craft_item(user, recipe)
  S->>DB: persist item & updates
  S->>F: evaluate_flags(user)
  F->>DB: query FLAG_REQUIREMENT for item/building
  F->>DB: check user state (items/buildings/etc.)
  alt requirements satisfied
    F->>DB: insert USER_FLAG (idempotent)
  end
  F-->>S: awarded flags (if any)
  S-->>C: success + message
  C-->>U: 200 OK (broadcast updates)
```

## Flow – Enforce before using gated Action

PNG: docs/feature_flags/diagrams/flow_enforce_flowchart.png

```mermaid
flowchart TD
  A[Start perform_action] --> B{Action has flag_id?}
  B -- No --> C[Proceed]
  B -- Yes --> D[Has USER_FLAG for flag_id?]
  D -- No --> E[Return 422 with requirements]
  D -- Yes --> C[Proceed]
  C --> F[Apply cooldowns/effects]
  F --> G[Persist + Broadcast]
  G --> H[Done]
```

## Flow – Backfill ensure flags

PNG: docs/feature_flags/diagrams/flow_backfill_flowchart.png

```mermaid
flowchart TD
  S[Start users:ensure_flags] --> U[Load users]
  U --> L[For each user]
  L --> Q[Compute satisfied flags from current state]
  Q --> I[insert_all missing USER_FLAG]
  I --> N{More users?}
  N -- Yes --> L
  N -- No --> D[Done]
```

Tips
- Pick Simple for speed-to-ship; pick Flexible for multi-model reuse and minimal schema churn.
- Show requirements in UI from `FLAG_REQUIREMENT` so users know how to unlock.
- Keep `users:ensure_flags` idempotent and fast via `insert_all` and proper indexes.
