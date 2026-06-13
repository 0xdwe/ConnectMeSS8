# Memory Topic Backfill and Topic-Scoped Suggestions PRD

Labels: prd, ready-for-agent, pass-4.3-follow-up

> Builds on: Pass 3 per-contact `MemoryDocument`, Pass 4.3 `LlmAiUpdate`, Topic Suggestions PRD, Firestore source-of-truth ADRs.
> Revises: the earlier Topic Suggestions decision that old memories receive no LLM backfill. This PRD creates one explicit, bounded backfill path because old Connections must receive useful Conversation Topics without each one requiring a manual AI Update.

## Problem Statement

Inside each Connection profile, Conversation Topics appear as tappable bubbles. The intended product behavior is that tapping a bubble gives a recommendation tied to that exact topic, informed by past conversations and current context.

Today the surface is inconsistent. Newer AI Update flows can write `MemoryDocument.topics` and prepared Topic Suggestions, but older Connections often have only generic seeded starter topics or no prepared suggestions. Topic taps can also show context that is not scoped to the selected bubble: global memory history, whole-person summary, or hardcoded placeholder news can make topic A display context from topic B. This makes the feature feel incorrect even though the memory substrate exists.

The user wants this fixed for all existing Connections. Old Connections should receive the feature now, not only after future manual updates. The app should use existing memory and recent CrmInteractions to generate topic-specific suggestions, without creating fake interactions or changing Bond Score.

## Solution

Add a one-shot, signed-in, background memory-topic backfill for existing Connections. After normal memory seeding completes, the app scans eligible Connections whose `MemoryDocument` has no prepared Topic Suggestions. For each eligible Connection, a new memory-only AI enrichment path reads the current `MemoryDocument` plus recent CrmInteractions, asks Gemini for ranked topic tags and topic-scoped suggestions, then saves an updated `MemoryDocument`.

This backfill does not create CrmInteractions, does not append history bullets, does not change Bond Score, and does not call the normal AI Update commit path. It only enriches the memory document's topics and topic suggestions.

The contact profile topic panel will also be tightened so selected-topic UI only shows content scoped to the selected bubble. It will show all prepared suggestions for that topic, remove hardcoded related-news placeholder content, and stop showing unfiltered history/summary sections that can reference another topic.

Backfill runs silently in the background. It is best-effort and non-blocking: normal app launch should not wait for Gemini. A versioned user-document sentinel records completion only when all eligible contacts succeed or are skipped. If any eligible contact fails, no sentinel is written; successful contacts are skipped next time because they now have Topic Suggestions, while failed contacts can retry on next launch.

## User Stories

1. As a ConnectMe user, I want Conversation Topic bubbles to reflect real things I have told the app, so that contact profiles feel personal instead of generic.
2. As a ConnectMe user, I want old Connections to gain AI topic suggestions automatically, so that I do not have to manually run Update with AI on every person.
3. As a ConnectMe user, I want tapping a topic bubble to show recommendations about that same topic, so that the result matches what I selected.
4. As a ConnectMe user, I want topic A to avoid showing context from topic B, so that I can trust the AI suggestion surface.
5. As a ConnectMe user, I want generic starter topics to disappear when better AI-ranked topics exist, so that useful topics are visible first.
6. As a ConnectMe user, I want the first four visible topic bubbles to be the most relevant topics, so that I do not have to hunt through generic tags.
7. As a ConnectMe user, I want topic recommendations to use past conversations and current memory, so that suggestions are more specific than templates.
8. As a ConnectMe user, I want topic recommendations to stay gentle and non-shaming, so that the app feels supportive.
9. As a ConnectMe user, I want app launch to stay fast while backfill runs, so that AI enrichment does not block me from using the app.
10. As a ConnectMe user, I want no noisy snackbar when background topic enrichment fails, so that transient AI failures do not interrupt me.
11. As a ConnectMe user, I want existing topic suggestions from a recent AI Update preserved, so that fresh high-quality AI output is not overwritten by a bulk job.
12. As a ConnectMe user, I want topic taps to show more than one useful suggestion when available, so that I have options for what to say or do.
13. As a ConnectMe user, I want blank or weak memories to avoid invented topic suggestions, so that the app does not hallucinate relationship context.
14. As a ConnectMe user, I want backfill to happen once for existing contacts, so that the app does not keep spending AI calls on the same memory.
15. As a ConnectMe user, I want future AI Updates to continue refreshing topics normally, so that ongoing conversation context stays fresh.
16. As a signed-in user, I want my Conversation Topic enrichment to live in my Firestore-backed memory, so that the enriched profile survives app restart.
17. As a signed-in user, I want signed-out state to do no topic backfill, so that background AI calls only happen for an authenticated account.
18. As a user with many Connections, I want backfill to process safely without flooding the model API, so that the app remains stable.
19. As a user with mixed old and new Connections, I want only missing Topic Suggestions backfilled, so that contacts already enriched by AI Update are skipped.
20. As a user whose backfill partially fails, I want failed contacts to retry later, so that one network or model failure does not permanently exclude them.
21. As a developer, I want memory-topic enrichment separate from AI Update, so that silent backfill cannot create interactions, history, or Bond Score changes.
22. As a developer, I want the backfill orchestrator to own persistence and sentinel writes, so that model generation and Firestore side effects remain separate.
23. As a developer, I want a versioned backfill sentinel, so that future prompt/schema versions can run a new backfill without ambiguous reset logic.
24. As a developer, I want tests at the memory-enrichment and provider orchestration seams, so that behavior is verified without depending on widget internals.
25. As a developer, I want Firestore rules to explicitly allow the new sentinel field and reject malformed writes, so that user-doc shape remains locked down.
26. As a developer, I want no `fake_cloud_firestore` dependency, so that tests follow the existing InMemory plus emulator/rules-test pattern.
27. As a product reviewer, I want the old no-backfill decision explicitly revised, so that future agents do not reapply the wrong PRD constraint.
28. As a product reviewer, I want topic recommendations to avoid numeric day-count guilt, so that the anti-shame guardrail still holds.

## Implementation Decisions

- Build a new `MemoryTopicEnricher` seam rather than reusing `AiUpdate`.
  - `AiUpdate` is a user-level operation that can create a CrmInteraction, append memory history, update next step, and move Bond Score.
  - Backfill is a memory-only enrichment operation and must not trigger those side effects.
- The production adapter is Gemini-backed and uses the existing Firebase AI provider pattern.
- The new seam returns an updated `MemoryDocument` candidate. It does not save directly.
- A background backfill orchestrator owns eligibility checks, recent-interaction lookup, memory saves, memory-epoch invalidation, retry behavior, and sentinel writes.
- Backfill starts only after normal memory seeding finishes, so the scan sees seeded memory docs for existing Connections.
- Backfill must not block first frame or the app shell. It is observed from the app shell only to start the background work.
- Backfill is signed-in only. Signed-out users do not construct or run the production enrichment path.
- Eligibility is limited to Connections whose `MemoryDocument` has no prepared Topic Suggestions.
- Existing prepared Topic Suggestions from AI Update are preserved; those contacts are skipped.
- Backfill uses `MemoryDocument` plus the most recent 10 CrmInteractions for that Connection.
- A contact is skipped if there is no useful source context: no meaningful memory text and no recent interactions.
- Generic seeded starter topics are removed when Gemini returns better topics. Starter topics include category-derived placeholders such as family, friends, work, college, and high school.
- Backfill topic ordering prioritizes Gemini-ranked new topics first, then preserves non-generic existing topics only if there is room.
- The topic cap remains the existing `MemoryDocument` cap.
- Backfill should ask Gemini for ranked short topic tags plus prepared Topic Suggestions for the selected topics.
- Topic Suggestions remain grouped under `MemoryDocument`; no sidecar Firestore collection is introduced.
- Each topic keeps up to three suggestions using the existing suggestion kinds: ask, share, plan, remember.
- Suggestions must be scoped to the selected topic and must not include unrelated topic context.
- Suggestions must remain gentle, actionable, and non-shaming. No numeric day-count guilt.
- Backfill is one-shot per user/version. It is not a continuous scheduler for future contacts.
- Future new Connections rely on normal AI Update to create topics/suggestions after the global sentinel has been written.
- Completion is recorded with a versioned user-document sentinel named `topicSuggestionsBackfillV1CompletedAt`.
- The sentinel is written only if all eligible contacts either succeed or are skipped.
- If any eligible contact fails, the sentinel is not written. Successful contacts will be skipped on later launches because they now have Topic Suggestions; failed contacts can retry.
- Processing should be serialized or tightly limited in concurrency. Concurrency 1 is preferred for the prototype to control API pressure.
- Failures are silent best-effort. No blocking UI and no snackbar.
- Logging is acceptable for debugging, but user-visible errors are out of scope.
- User consent UI is not required for this prototype because the app already presents itself as AI-backed and the user explicitly wants all existing Connections enriched.
- The contact profile topic panel should show all prepared suggestions for the selected topic when present.
- The contact profile topic panel should remove hardcoded related-news placeholder content.
- The contact profile topic panel should stop showing unfiltered history and whole-person summary under a selected topic because those can mismatch the bubble.
- No new topic evidence/snippet field is added in this PRD. Topic-specific suggestions are the trusted scoped content.
- Firestore user-document validation must allow the new optional timestamp sentinel and reject wrong types or extra fields according to existing rules style.
- This work respects ADR-0002: no `fake_cloud_firestore`; use InMemory adapters/providers for headless tests and rules/emulator tests for Firestore behavior.
- This work respects ADR-0003: cross-device evidence remains deferred unless the user decides it is load-bearing.
- This work respects ADR-0004: Firestore remains the durable source of truth for memory and the user-document sentinel.
- This work does not alter ADR-0005: AppController remains the write coordinator for relationship graph writes, but backfill does not need to add a new AppController mutating method because it only updates memory and sentinel state.

## Testing Decisions

- Test external behavior at seams, not implementation details or private helper names.
- Add unit tests for `MemoryTopicEnricher` projection/merge behavior using deterministic fake model output.
- Add unit tests that generic starter topics are removed when better topics arrive.
- Add unit tests that Gemini-ranked topics appear before preserved non-generic existing topics.
- Add unit tests that existing Topic Suggestions cause a contact to be skipped.
- Add unit tests that contacts with no useful memory or interactions are skipped without model calls.
- Add unit tests that backfill does not create CrmInteractions, does not append history, and does not change Bond Score.
- Add provider/orchestrator tests with InMemory `MemoryStore` and fake `MemoryTopicEnricher`.
- Add provider/orchestrator tests that backfill runs after memory seeding and does not block app startup behavior.
- Add provider/orchestrator tests that sentinel is written only after all eligible contacts succeed or are skipped.
- Add provider/orchestrator tests that sentinel is not written when any eligible contact fails.
- Add provider/orchestrator tests that a second launch skips contacts already enriched with Topic Suggestions.
- Add widget tests for contact profile topic panel behavior.
- Widget tests should verify that tapping a topic shows all prepared suggestions for that topic.
- Widget tests should verify that selecting topic A does not show topic B suggestions.
- Widget tests should verify hardcoded related-news placeholder copy is gone.
- Widget tests should verify unfiltered history/summary content no longer appears under selected topic details.
- Add pure `ConversationTopics` tests if helper behavior changes for preferred suggestions.
- Add Firestore rules tests allowing owner writes of `topicSuggestionsBackfillV1CompletedAt` as a timestamp.
- Add Firestore rules tests denying wrong type, cross-user write, anonymous write, and extra disallowed fields for the sentinel.
- Prefer targeted test runs: state tests for backfill/enricher, widget tests for profile topic panel, JS rules tests for rules changes.
- Do not require full `flutter test` sweep unless the user explicitly approves it.
- Do not require integration-test emulator evidence for this PRD unless ADR-0003 revisit triggers fire.

## Out of Scope

- No continuous background scheduler for future Connections after the one-shot v1 backfill completes.
- No lazy Gemini call when a topic bubble is tapped.
- No message drafting, SMS/email integration, or send action.
- No new Firestore sidecar collection for Topic Suggestions.
- No new topic evidence/context-snippet field in `MemoryDocument`.
- No Home recommendation ranking change in this PRD.
- No Bond Score changes from backfill.
- No new CrmInteraction from backfill.
- No memory history append from backfill.
- No visible progress UI, snackbar, or opt-in banner for the prototype slice.
- No cross-device verification requirement beyond existing deferred evidence policy.

## Further Notes

This PRD intentionally changes the earlier no-backfill stance because the user's current requirement is that old Connections receive the Conversation Topics feature now. The change is bounded: one-shot, versioned, memory-only, signed-in, silent, and idempotent.

The most important correctness property is topic scoping. A selected topic bubble must not render unrelated context. If the app cannot produce a topic-specific suggestion, it should fall back to deterministic topic templates rather than showing global memory history, whole-profile summary, or placeholder news.

The second important correctness property is side-effect isolation. Backfill enriches `MemoryDocument` only. It must never pretend the user had a new conversation, never alter relationship strength, and never create timeline history.
