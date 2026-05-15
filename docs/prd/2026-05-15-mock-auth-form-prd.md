# Mock Auth Form PRD

## Problem Statement

ConnectMe currently starts with a single mock workspace button. The usability test script asks participants to sign up for a new account or log in with email and password. This mismatch makes the first task feel unrealistic and may confuse participants before they reach the core relationship management flow.

## Solution

Replace the current entry button with a real-looking mock authentication form. Users can switch between Log in and Sign up. Log in accepts any valid email/password pair and enters the app. Sign up collects full name, email, password, and confirm password, validates the fields, updates the displayed profile name/email for the session, and enters the app.

The feature remains prototype-only: no backend, no persistence, no real accounts.

## User Stories

1. As a usability test participant, I want to see a login form, so that the app feels like a real mobile app.
2. As a usability test participant, I want to enter my email and password, so that I can complete the login task from the script.
3. As a usability test participant, I want the login form to accept valid-looking credentials, so that I am not blocked by missing backend accounts.
4. As a usability test participant, I want to see clear validation messages, so that I understand what to fix if I leave fields blank.
5. As a usability test participant, I want to sign up if I do not have an account, so that the scripted task supports both paths.
6. As a usability test participant, I want to enter my full name during signup, so that the app can personalize the session.
7. As a usability test participant, I want to enter my email during signup, so that my profile reflects the account I created.
8. As a usability test participant, I want to create a password during signup, so that the signup flow resembles a real app.
9. As a usability test participant, I want to confirm my password, so that I can catch typing mistakes.
10. As a usability test participant, I want the app to tell me when passwords do not match, so that I can complete signup successfully.
11. As a usability test participant, I want the app to accept simple valid credentials, so that prototype validation does not distract from relationship management tasks.
12. As a usability test participant, I want to switch between login and signup easily, so that I can choose the path that matches the prompt.
13. As a usability test participant, I want to land on the home page after login, so that I can continue to recommendations.
14. As a usability test participant, I want to land on the home page after signup, so that I can continue the test without extra setup.
15. As a usability test participant, I want my signed-up name to appear in the app header/profile, so that the signup feels connected to the app.
16. As a usability test participant, I want my signed-up email to appear in the profile page, so that the account information is consistent.
17. As a project evaluator, I want the auth flow to match the usability script, so that task success can be measured fairly.
18. As a developer, I want this auth flow to stay mock-only, so that we avoid backend scope during the prototype assignment.
19. As a developer, I want validation to be local and simple, so that the auth form remains easy to understand and maintain.
20. As a developer, I want tests around the auth behavior, so that future UI changes do not break the usability test entry flow.

## Implementation Decisions

- Build one auth screen with two modes: Log in and Sign up.
- Use a visible mode switch or equivalent toggle between the two auth modes.
- Log in fields: email and password.
- Sign up fields: full name, email, password, and confirm password.
- Validation is intentionally light: required fields, email contains `@`, password length is at least 6 characters, and signup passwords match.
- Any valid login credentials succeed.
- Sign up updates the session user name and email before entering the app.
- Existing mock app data remains unchanged after signup except for the displayed user profile fields.
- Keep the implementation mock-only with no backend, network call, token storage, account persistence, or real credential checking.
- Keep authentication errors local to the auth form rather than adding global auth error state.
- Preserve the existing app route after successful auth.
- Preserve the existing sign out behavior returning to the auth screen.

## Testing Decisions

- Good tests should verify external behavior visible to users, not internal widget structure or private helper methods.
- Test the auth form module through widget interactions: entering text, tapping submit, and observing navigation or validation messages.
- Test successful login with valid email/password and confirm the app enters the main shell.
- Test successful signup with valid full name/email/password/confirmation and confirm the profile/header reflects the signed-up user.
- Test invalid login/signup fields and confirm validation messages are shown.
- Prior art exists in the current widget tests that pump the app and interact with visible controls.
- Prior art exists in state tests for app controller behavior; add a focused state test only if signup logic is added to the session state module.

## Out of Scope

- Real backend authentication.
- Firebase, Supabase, OAuth, Apple login, Google login, or email verification.
- Persistent accounts across app restarts.
- Password recovery.
- Strong password policy.
- Account deletion.
- Router guards beyond the current prototype flow.
- Changes to recommendations, people, planner, AI update, heatmap, or settings beyond using the signed-up profile fields.

## Further Notes

This PRD supports the assignment usability script. The goal is not secure authentication; the goal is a believable prototype entry flow that lets participants complete the scripted login/signup task without backend friction.
