# TODO - Mobile

> **AI INSTRUCTIONS:** This file tracks pending work for the Bleya mobile app.
> - When the user asks "what's left to do?" or similar, read this file and summarize open items.
> - **Do NOT start, implement, or modify any item below without explicit approval from the user.**
> - When an item is completed, move it to the "Done" section with the date.
> - A matching `TODO.md` exists in the backend repo. Items marked _(shared)_ appear in both.

---

## Open

### 1. Human-readable errors _(shared)_
Audit all errors that can surface to the end user and ensure they are human-readable.
- Review mobile error handling / displayed messages
- Review how backend error responses are rendered in the UI
- Replace technical/stacktrace-style messages with user-friendly copy
- Ensure consistent tone and formatting across the app

### 2. User-facing strings audit
Review every string the user sees and flag anything off-standard, then propose replacements.
- Error messages
- General UI texts / labels / buttons
- Permission prompts (iOS `Info.plist` usage descriptions, Android runtime permission rationales)
- Empty states, loading states, confirmations
- Deliverable: list of non-compliant strings + proposed changes (no edits until approved)

### 3. Legal / policies before go-live _(shared)_
Identify and prepare all legal documents and compliance items required before launch.
- Terms & Conditions
- Privacy Policy
- Cookie / tracking policy (if applicable)
- GDPR / data handling disclosures
- Age rating / content guidelines
- Store listing legal requirements (Apple App Store, Google Play)
- In-app links / acceptance flow
- Account deletion flow (required by both stores)

### 4. App icon
Design and integrate the final app icon.
- Produce master asset
- Generate all required sizes (iOS + Android, adaptive icon for Android)
- Replace placeholder icons in both platforms
- Verify on device

---

## Done

_(empty)_
