# Loading UI Rules

This is the source of truth for loading behavior in the Flutter app.

## Core rule

Always use shared loading widgets:

- `AppSpinner` from `lib/widgets/app_spinner.dart`
- `AppSkeleton` from `lib/widgets/app_skeleton.dart`

Do not use `CupertinoActivityIndicator`, `CircularProgressIndicator`, or custom one-off shimmer blocks directly in pages/widgets.

## When to use `AppSkeleton`

Use skeletons for content loading where the final layout is known:

- Room lists, chat lists, thread content
- Profile/details pages
- Cards, rows, and sections that already have a stable shape

Skeletons should roughly match the final layout (size, spacing, hierarchy) so loading feels intentional and reduces visual jump.

## When to use `AppSpinner`

Use spinner for short action-level loading:

- Button submit/loading states
- Inline operations (join, save, retry)
- Transitional boot/loading where layout is not yet known

Do not use full-screen spinner for content-heavy screens when a skeleton can be shown.

## Timing guidance

- Under ~300ms: show nothing
- ~300ms to ~1s: spinner is acceptable
- Over ~1s with known layout: skeleton preferred

## Error and retry policy

Any non-trivial loading state must have a visible failure path:

- Show an error state/message
- Provide retry action where practical
- Avoid indefinite loading without fallback

## Code review checklist

- No direct usage of `CupertinoActivityIndicator`/`CircularProgressIndicator` in screens/components
- Content loaders use `AppSkeleton`
- Action loaders use `AppSpinner`
- Loading states have matching error/empty handling
