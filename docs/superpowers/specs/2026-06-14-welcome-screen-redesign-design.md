# Welcome & Login Screen Layout Redesign

**Date:** 2026-06-14  
**Status:** Approved  
**Author:** Antigravity

## Context

The Welcome/Landing screen and Log In/Sign Up screen backgrounds were previously scaling with `BoxFit.cover` inside a full-screen `Positioned.fill` widget. On tall mobile devices (e.g., standard Android/iOS emulator aspect ratios like 9:20), this caused severe side cropping of the background templates. Essential decorative elements (such as the pink sphere, stars, and portions of the bottom character's waving hand and side bubbles) were clipped. Additionally, the buttons had capsule shapes instead of the rounded rectangles shown in the mockup design, and the text was not perfectly centered.

This design document specifies the changes to correct the background fitting, spacing, and button styles to match the mockup exactly.

## Proposed Changes

### 1. Background Fitting & Blending (Approach A)

* **Welcome/Landing Page Background Stack:**
  - Introduce a background container with a matching linear gradient `[Color(0xFFE6DBFB), Color(0xFFFAF7FC)]` running from top-left to top-right.
  - Position the background image using `BoxFit.fitWidth` and `Alignment.bottomCenter`.
  - On tall screens, the top of the image will terminate below the status bar. The gradient container underneath will fill the top gap, blending seamlessly with the image's top edge. The bottom character and side elements will scale down to fit the screen width, avoiding any side cropping.

* **Log In / Sign Up Background Stack:**
  - Introduce a background container with a solid `Colors.white` color.
  - Position the background image using `BoxFit.fitWidth` and `Alignment.topCenter`.
  - The image will scale to fit the screen width at the top, leaving a white gap at the bottom that blends seamlessly with the white container underneath.

### 2. Spacing Adjustments

We will adjust the spacing in the landing layout `Column` based on screen height (`MediaQuery.sizeOf(context).height`) to keep elements neatly positioned within the template's blank areas:
- **Top padding:** `height * 0.08` (pushes logo below the top wave).
- **Logo to headline:** `height * 0.06`.
- **Headline to actions:** `height * 0.05`.
- **Bottom padding:** Maintain `Spacer()` at the bottom.

### 3. Action Buttons Redesign

- **Shape:** Replace `StadiumBorder` with `RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))`.
- **Width:** Increase button max width from `290` to `325`.
- **Layout:** Center text exactly and place a right arrow `->` on the right side using a `Stack` layout.
  - **Sign Up Button:** Solid purple background (`tokens.primary`), white text, white arrow.
  - **Log In Button:** White background, thin purple border (`tokens.primary.withOpacity(0.35)`), purple text, purple arrow.

## Verification Plan

### Automated Tests
- Run existing widget/unit tests:
  - `flutter test test/features/auth_screen_test.dart`
  - `flutter test test/features/auth_screen_profile_test.dart`

### Manual Verification
- Run the app on the emulator and confirm that:
  - The stars, circle, and character are fully visible without cropping on the sides.
  - The buttons are rounded rectangles and text is centered.
  - The transition to Login/Signup works correctly and the background fits properly.
