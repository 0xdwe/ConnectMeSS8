# #058 Auth-aware memoryStoreProvider rebuild

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-24-firebase-memory-store-pass-4-2-prd.md

## What to build

Make production `memoryStoreProvider` watch auth state: signed-in users get a UID-bound `FirebaseMemoryStore`; signed-out access throws loudly. Auth changes rebuild the store and invalidate downstream memory consumers.

## Acceptance criteria

- [ ] Signed-in provider returns `FirebaseMemoryStore` bound to current Firebase UID.
- [ ] Signed-out memory access throws a clear failure.
- [ ] Sign-out/sign-in-as-other-user swaps store identity completely.
- [ ] `memoryProvider`, `memoryTopicsProvider`, `recommendationsProvider` rebuild/invalidate on store identity changes.
- [ ] Provider tests use existing `ProviderContainer` style.
- [ ] No user memory can leak across auth-user changes.

## Blocked by

- #057
