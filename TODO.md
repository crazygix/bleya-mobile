# TODO - Mobile

> **AI INSTRUCTIONS:** This file tracks pending work for the Bleya mobile app.
> - When the user asks "what's left to do?" or similar, read this file and summarize open items.
> - **Do NOT start, implement, or modify any item below without explicit approval from the user.**
> - When an item is completed, remove it from this file.
> - A matching `TODO.md` exists in the backend repo.

---

## Open

### 1. Human-readable errors
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

### 3. Legal / policies before go-live
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

### 5. README cleanup
Go through all `README.md` files in the repo and make them short and readable.
- Keep only a straight explanation of what the project is and how to run it
- Remove debugging notes, troubleshooting dumps, outdated sections, and other noise
- Ensure consistent structure and tone

### 6. Dead code cleanup
Remove unused / dead code and anything that causes confusion.
- Unused files, classes, functions, variables, imports
- Commented-out code blocks left behind
- Obsolete feature flags, leftover experiments, stale TODOs
- Duplicate or redundant implementations
- Deliverable: list of candidates for removal before deleting (no edits until approved)

### 7. Push notification appearance
Change the in-app push notification view to use a dark background, matching the native iOS style and popular apps.
- Update styling to dark background with appropriate contrast for title/body
- Verify on iOS and Android
- Ensure readability in both light and dark system themes
