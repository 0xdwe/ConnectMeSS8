# Welcome & Login Screen Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modify the Landing page and Login/Signup screen layout, buttons, and background fitting to perfectly match the mockup design and prevent background clipping.

**Architecture:** We will implement Approach A where background templates are rendered with `BoxFit.fitWidth` and aligned to the bottom (Landing) or top (Login/Signup). Underneath, a matching gradient or solid white color fills any remaining empty screen space, creating a seamless full-bleed look. Action buttons will be updated to rounded rectangles with a max width of 325, with text centered and arrow icon positioned on the right using a `Stack`.

**Tech Stack:** Flutter, Dart, Riverpod

---

### Task 1: Refactor Background Layers in AuthScreen

**Files:**
- Modify: [auth_screen.dart](file:///C:/Users/sukse/ConnectMeSS8/lib/src/features/auth_screen.dart) (lines 264-288)

- [ ] **Step 1: Update background stack for Landing and Login/Signup screens**
  Modify the Stack children corresponding to the background image rendering in `lib/src/features/auth_screen.dart`.
  
  Replace lines 264-288 with:
  ```dart
              // 1. Mode-specific background
              if (_mode == AuthMode.landing) ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFE6DBFB),
                            Color(0xFFFAF7FC),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.topRight,
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Image(
                      key: Key('welcome-screen-background'),
                      image: AssetImage('assets/images/welcome_back.jpg'),
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.bottomCenter,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ] else ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.white,
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Image(
                      key: Key('login-page-background'),
                      image: AssetImage('assets/images/login_page.jpg'),
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ],
  ```

- [ ] **Step 2: Run verification tests**
  Run targeted tests to make sure there are no compile errors and basic background expectations still pass.
  Run: `flutter test test/features/auth_screen_test.dart`
  Expected: PASS

- [ ] **Step 3: Commit changes**
  ```bash
  git add lib/src/features/auth_screen.dart
  git commit -m "feat: implement width-fitting and blending for welcome and login backgrounds"
  ```

---

### Task 2: Redesign Welcome Layout, Spacing, and Action Buttons

**Files:**
- Modify: [auth_screen.dart](file:///C:/Users/sukse/ConnectMeSS8/lib/src/features/auth_screen.dart) (lines 386-522)

- [ ] **Step 1: Refactor vertical layout spacers and action buttons shape/content**
  Modify `_buildLanding` inside `lib/src/features/auth_screen.dart`.
  
  Replace the entire `_buildLanding` method with:
  ```dart
    Widget _buildLanding(BuildContext context, AppTokens tokens) {
      final height = MediaQuery.sizeOf(context).height;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: height * 0.08),
          // App logo & title
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinkedChainLogo(
                  size: 60,
                  color: tokens.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect Me',
                  style: AppTypography.bodyLg(color: tokens.ink).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: height * 0.06),
          // Welcome headline and subtext
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome to\nConnect Me',
                  textAlign: TextAlign.center,
                  style: AppTypography.glyph(
                    36,
                    color: tokens.ink,
                    weight: FontWeight.w700,
                  ).copyWith(height: 1.15),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nurture the relationships\nthat matter most.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(color: tokens.inkMuted).copyWith(
                    height: 1.3,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: height * 0.05),
          // Actions
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 325),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sign Up
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _switchMode(AuthMode.signup),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              'Sign Up',
                              style: AppTypography.bodyLg(color: Colors.white).copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Icon(Icons.arrow_forward, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Log In
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => _switchMode(AuthMode.login),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: tokens.primary,
                        side: BorderSide(
                          color: tokens.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              'Log In',
                              style: AppTypography.bodyLg(color: tokens.primary).copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Icon(Icons.arrow_forward, size: 18, color: tokens.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      );
    }
  ```

- [ ] **Step 2: Run verification tests**
  Run targeted tests to verify everything passes.
  Run: `flutter test test/features/auth_screen_test.dart`
  Expected: PASS

- [ ] **Step 3: Commit changes**
  ```bash
  git add lib/src/features/auth_screen.dart
  git commit -m "feat: redesign landing layout spacing and action buttons to match mockup spec"
  ```

---

### Task 3: Final Verification and Integration Testing

**Files:**
- Test: [auth_screen_test.dart](file:///C:/Users/sukse/ConnectMeSS8/test/features/auth_screen_test.dart)

- [ ] **Step 1: Execute all auth screen and profile tests**
  Verify the full suite of related tests:
  Run: `flutter test test/features/auth_screen_test.dart test/features/auth_screen_profile_test.dart`
  Expected: PASS (no regressions or layout failures)

- [ ] **Step 2: Commit any test adjustments**
  If any test logic needed minor alignment adjustment due to button shapes:
  ```bash
  git add test/features/auth_screen_test.dart
  git commit -m "test: align auth tests with redesigned layout and rounded buttons"
  ```
