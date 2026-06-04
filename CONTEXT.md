# ConnectMe — Domain Context

Single-source-of-truth glossary for the ConnectMe codebase. Use these terms exactly when discussing features, designs, PRDs, issues, or commits. Add to this file when a new domain concept earns a name; refine in place when a term sharpens during grilling.

This file complements `docs/prd/` (per-pass design narratives) and `docs/adr/` (cross-cutting decisions). Read it first when landing in the codebase; it's the cheapest way to load the language.

---

## What ConnectMe is

ConnectMe is a personal-CRM Flutter app for tracking the relationships you actually want to maintain. The user adds contacts ("Sarah," "Mike"), logs interactions with them ("had coffee on Tuesday"), schedules events ("call Sarah next week"), and gets AI-driven recommendations about who to reach out to. The relationship graph persists in Firestore; signed-out, you see nothing.

Single-device prototype scope as of 2026-05-26: cross-device sync is wired but not formally evidenced.

---

## Core domain terms

### Connection
A person the user is tracking. The fundamental unit of the relationship graph. Each Connection has a `bondScore` (0..100), a `category` (user-classified, default Family/Friends/Work), an `avatar` (emoji or image), and a `nextStep` (one-line suggestion for the next interaction). Connections live at `users/{uid}/connections/{contactId}` in Firestore. The `id` field equals the document key (rules-enforced).

The seeded sample connections (Mike, Sarah, Emily, David) are flagged `isSample: true` so the user can clear them.

### CrmInteraction
An entry in a Connection's history. The user logs them when something happens ("had coffee," "shared a podcast link") OR the AI suggests them via `applyAiUpdateResult`. Each interaction has a `type` (one of `InteractionType` enum: interaction, personalDetail, preference, reminder, sharedActivity, relationshipNote), a `source` (manual or aiSuggested), a `title`, a `note`, a `date`, and optional `attachments`. Interactions live at `users/{uid}/interactions/{interactionId}`.

CrmInteractions are NOT memories (see below). Memories are LLM-generated narrative; interactions are atomic timeline events.

### PlannerEvent
An item on the user's planner. Has a `date`, an `eventType` (user-classifiable: Coffee, Meeting, Birthday, Reminder, etc.), an optional `contactId` link to a Connection, optional `startTimeMinutes` / `endTimeMinutes`, optional `recurrencePattern` (daily/weekly/monthly/yearly). Events live at `users/{uid}/events/{eventId}`. The `eventType` enum is per-user data — the user can rename or add types — so the rules layer does NOT validate it server-side (PRD §Q8 of Pass 4.5).

### MemoryDocument
A per-contact narrative document. Pass 3's central artifact. Markdown with YAML frontmatter; contains five sections: `Summary`, `History`, `Preferences`, `Topics`, `Upcoming`. Grows on every "Update with AI" run. Stored at `users/{uid}/memories/{contactId}`. The 64KB per-contact cap drops oldest history bullets when exceeded.

MemoryDocument is the LLM-readable shape of a relationship; CrmInteraction is the timeline event shape; both reference the same Connection.

### Bond Score
A 0..100 integer on each Connection that represents relationship strength. Stored, not derived (PRD §Q11 of Pass 4.5). Mutated by `applyAiUpdateResult` using the diminishing-returns curve `floor(interactionDepth × (100 − currentBond) / 160)`, where `interactionDepth` is the LLM's 0..100 judgment of how content-rich the AI Update input was (Pass 4.3 PRD §Q6 / #085). Same input moves a low-bond contact much more than a high-bond contact. The seeded values (95/85/73/68/92) have no derivation rule. Bond Score is not a raw recency counter or activity streak; Relationship Graph maintenance uses separate Maintenance Need and Bond Drift concepts. The `BondRing` widget visualizes it as a ring with a tier color.

### Bond Tier
A coarse bucketing of Bond Score: close (80..100), steady (50..79), drifting (0..49). Used by `BondRing` for ring color and by relationship-maintenance policy for durability and Bond Drift caps.

### Maintenance Need
A derived, not stored, recommendation-urgency signal for a Connection. It compares elapsed time since the latest touch to the Connection's adjusted maintenance cadence. Latest touch is `max(Connection.lastContact, latest CrmInteraction.date for the same Connection)`, falling back to `Connection.lastContact` when no interactions exist. Maintenance Need can rise before Bond Drift applies and never mutates data.

### Bond Drift
A bounded Bond Score decrease applied rarely when a Connection is clearly outside its calibrated maintenance rhythm. Bond Drift is bucketed, not continuous, capped at -3 per application, and guarded by `Connection.lastBondDriftAppliedAt` with a 7-day minimum application window. `AppController` is the only application hook; `RecommendationEngine` never mutates state.

### AI Update
The user-level operation "tap Update with AI on a contact, see what changed, accept or cancel." Implemented by the `AiUpdate` interface (Pass 3 §Q1) — one method `run` (purely constructive: returns a result, doesn't write) and one method `commit` (writes memory, then state, all-or-nothing rollback on failure). Today the only adapter is `MockAiUpdate`; Pass 4.3 will add `LlmAiUpdate`.

The AI Update flow produces an `AiUpdateResult` value: a new CrmInteraction, an updated MemoryDocument, a bondScore bump.

### Recommendation
A "you should reach out to X" card on the home screen. Produced by `RecommendationEngine` (a pure function ranking the live Connection list by bond-tier-weighted recency, top 3, 24h cooldown). Cached via `recommendationsProvider` with dual invalidation (memory change OR 6h elapsed).

### Relationship Graph
The shared shape of (Connections, CrmInteractions, PlannerEvents) — the user's people, their history, and their forward plan. NOT a single data structure; rather, the joint result of three Firestore subcollections that are mutated atomically when their cardinality crosses (e.g. deleteConnection cascades to interactions and events in one batched write).

---

## Architectural terms

(Per-skill vocabulary from `improve-codebase-architecture/LANGUAGE.md`. Listed here as a quick reference; the full definitions live in the skill.)

- **Module** — anything with an interface and an implementation.
- **Interface** — everything a caller must know to use the module: types, invariants, error modes, ordering, config.
- **Seam** — where an interface lives.
- **Adapter** — a concrete thing satisfying an interface at a seam.
- **Depth** — leverage at the interface.
- **Locality** — what maintainers get from depth: change concentrates in one place.

---

## Key seams in the current codebase

These are the named places behavior can be altered without editing in place. Each has at least two adapters (the threshold for a real seam, not a hypothetical one).

### `MemoryStore`
Per-contact memory persistence. Adapters: `InMemoryMemoryStore` (test), `FileMemoryStore` (debug/migration source), `FirebaseMemoryStore` (production). Pure `.get()` / `.set()` / `.delete()` shape; no listener.

### `ConnectionStore` / `InteractionStore` / `EventStore`
Pass 4.5 store seams for the relationship graph. Adapters per family: `InMemory*` (test), `Firebase*` (production). Each exposes async `load` / `save` / `delete` / `listAll` PLUS `Stream<Map<String, T>> snapshot()` PLUS synchronous `Map<String, T>? snapshotSync()` mirror PLUS idempotent `dispose()`.

The snapshot pair is the new pattern Pass 4.5 introduced; Pass 4.2 deliberately did not pay for it (PRD §Q6).

### `UserDocStore`
Pass 4.5 seam for user-document fields (`categories`, `eventTypes`, seeder sentinels). Single document at `users/{uid}`, not a collection. Always uses `set + merge: true` so seeder sentinels are never clobbered.

### `BatchedWrites`
Pass 4.5 seam for multi-store atomic writes. Three named operations: `commitDeleteConnection`, `commitAiUpdate`, `commitRemoveSampleConnections`. Adapters: `InMemoryBatchedWrites` (test, with `failOnCommit` knob), `FirebaseBatchedWrites` (production, real `WriteBatch.commit()`), `_SignedOutBatchedWrites` (sentinel that throws).

### `AiUpdate`
Pass 3 §Q1 carve. The "Update with AI" flow as a single module. Adapters: `MockAiUpdate` (deterministic Pass 3), `LlmAiUpdate` (Pass 4.3, not yet built).

### `AppController`
Currently the umbrella Notifier holding 27 mutating methods. Pass 4.5 made every mutating method write through one of the seams above. AppController itself is NOT a clean seam (the deletion test would mostly redistribute, not concentrate); see `docs/adr/` for any future carve decisions.

---

## Source-of-truth contracts

After Pass 4.5 (commit `2889b59`):

- **Firestore is the source of truth** for connections, interactions, events, categories, event types, and per-contact memory. AppController state is a denormalization of the four store snapshot mirrors plus the in-memory user-doc snapshot.
- **Cross-instance writes flow in via snapshot listeners.** A write on device A propagates to device B's listener, into the mirror, into AppController state, into the UI.
- **First-launch initialization is via `ConnectionSeeder`**, not a migration. Sentinels (`*SeededAt`, `migratedFromDiskAt`) gate idempotency.
- **Multi-store writes are atomic** via `BatchedWrites`. `deleteConnection`, `applyAiUpdateResult`, `removeSampleConnections` all use Firestore `WriteBatch`. On commit failure, AppController state is not advanced.
- **Sign-out is trivial** post-#070. The auth-aware provider rebuild + listener teardown clears state on sign-out; the next sign-in's snapshot listeners refill from Firestore.

---

## Anti-patterns / things this codebase deliberately rejects

- **`fake_cloud_firestore`** is forbidden (Pass 4.2 PRD §Q9 + Pass 4.5 PRD §Q9). Headless tests use `InMemory*Store` adapters; emulator tests use the real Firebase emulator.
- **Numeric overdue/shame copy in proactive nudges** (Pass 3 anti-shame guardrail, refined by #090): recommendation cards must not say "you haven't talked to Mike in 47 days" or frame silence as neglect/decay. The copy is gentler ("Mike could use a check-in"). Neutral elapsed-time facts are allowed on user-pulled detail surfaces such as contact profile (for example, "Last connected: 3 weeks ago") when not framed as guilt.
- **Background scheduling** is out of scope; Pass 4.4's FCM push will fill that gap. Today, the recommendation cache invalidates on app open or memory change.
- **`AppUser` is dead code** (PRD Q13 of Pass 4.5). It duplicates `currentUserProvider`. Cleanup is filed but deferred.

---

## How this file is maintained

This file is updated lazily when a term sharpens during grilling, when a new module earns a domain name, or when an ADR is recorded that changes a contract. It is NOT updated for every commit — that's progress.md's job. Refer to `docs/adr/` for cross-cutting decisions and `docs/prd/` for per-pass narratives.
