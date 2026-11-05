# CurrencySpot

## String catalogs

- Write `.xcstrings` entries in the layout Xcode saves: every object and array spread over separate lines, never a whole localization on one line. Xcode rewrites any other layout on its next build.
- Discard Xcode's edits to `AppShortcuts.xcstrings`. It marks the phrase translations "needs review" and `Convert currency to ${to} with ${applicationName}` as stale, but the app looks up each phrase by its own key. Never remove its stale strings, because that deletes the phrase's translations.
