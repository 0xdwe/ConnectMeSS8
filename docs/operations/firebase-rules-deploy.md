Labels: docs

# Firebase rules: CI deploy setup

## Why this exists

Firestore rules in `firestore/firestore.rules` only protect the live `connect-me-e20b1` project once they have actually been deployed. As the team moves from one developer to five, "remember to deploy after merge" becomes a coordination problem. #055 hands that to CI: PRs that touch rules run the JS rules tests, and merges to `main` that change the rules file deploy them automatically. This doc covers the one-time setup so the deploy workflow can authenticate.

## One-time setup (HITL)

1. In the Google Cloud Console for `connect-me-e20b1`, create a service account named `firebase-rules-deployer` (or similar). Grant the role **Firebase Rules Admin** (`roles/firebaserules.admin`). This role is intentionally narrower than Editor or Owner — least privilege, blast radius bounded to rules.
2. Generate a JSON key for that service account and download it.
3. In the GitHub repo, go to Settings → Secrets and variables → Actions → New repository secret. Name the secret `FIREBASE_SERVICE_ACCOUNT`. Paste the entire JSON contents (including the surrounding `{ ... }`).
4. Verify the wiring by opening a no-op rules change PR (e.g. tweak a comment in `firestore/firestore.rules`), merging it to `main`, and watching the `Firestore rules deploy` workflow turn green.

## What runs when

The PR check (`.github/workflows/rules-tests.yml`) runs on every pull request that touches anything under `firestore/**`. The deploy workflow (`.github/workflows/rules-deploy.yml`) runs only on merges to `main` that change `firestore/firestore.rules`, runs the same rules tests first, and then deploys with `firebase deploy --only firestore:rules`. Nothing else gets deployed by this workflow.

## Failure modes

- **Deploy job is red and says "FIREBASE_SERVICE_ACCOUNT secret is not configured"** — set the secret using the steps above. Until then, manual `firebase deploy --only firestore:rules` from a teammate's laptop is the fallback.
- **Deploy job is red and says permission denied** — the service account is missing the Firebase Rules Admin role. Re-grant it in Google Cloud Console.
- **Tests are red on the PR check** — fix the rules or the rules tests. Don't bypass the check; the rules tests are the only automated guard between a typo and a production lockout.

## Rollback

Firebase keeps a rules history in the console. If a deploy is wrong, open the Firestore rules tab and revert to the previous version with one click. As an alternative, revert the rules commit on `main`; the deploy workflow will redeploy the prior version on the next merge.
