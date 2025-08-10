### Purpose
Track medium/long‑term improvements without changing existing code now. Prioritized, actionable items.

### Short-term (next 1–2 weeks)
- **Fix analyzer warnings**: Remove unused import in `lib/presentation/providers/form_provider.dart`.
- **Validate Flutter/Dart versions**: Ensure the project targets a recent stable Flutter. If `Color.withValues(...)` compatibility is uncertain, replace with `withOpacity(...)` for broader support.
- **Secrets management**: Move OAuth `serverClientId` to env/config (e.g., `flutter_dotenv`) and document per‑platform setup.
- **Manual sync UI**: Add a button/menu to trigger `GoogleSheetsService.manualSync()` and show basic sync status (`pending/synced/failed`).
- **Auth UX**: Improve sign‑in prompts and error messaging; handle cancellation cleanly with guidance.
- **Date handling**: Centralize DD/MM/YYYY formatting/parsing and ensure timezone correctness (Israel TZ) across devices.
- **Autocomplete refresh**: Add pull-to-refresh for suggestions; auto-refresh on successful save is already present.

### Google Sheets/Drive robustness
- **Search reliability**: In Drive queries, consider advanced filters and pagination; optionally set `supportsAllDrives` and clarify ownership vs shared access in logs.
- **Batch operations**: Use `spreadsheets.values.batchUpdate` for grouped writes; reduce API calls and rate-limit issues.
- **Protection logic**: Reconfirm protected range applies to correct `sheetId` and gracefully degrade if protection fails.
- **Insert position**: Extend sorting/insert logic to educator sheets as well (currently append‑only there).
- **Error taxonomy**: Normalize network/quota/permission errors; map to user‑friendly RTL messages and retry guidance.

### Multi-destination save (educator sheets)
- **Ownership verification**: Keep current check but add clearer user guidance when the educator hasn’t shared edit access.
- **Caching**: Cache educator spreadsheet IDs per email with TTL; invalidate cache on permission errors.
- **Config UI**: On the educator settings screen, add a quick test button to verify access to each mapped educator sheet.

### Offline-first enhancements
- **Exponential backoff**: For failed syncs, backoff by retry count; cap retries and surface status in UI.
- **Conflict resolution**: If the same 4-key record exists online with different scores, define a policy (latest timestamp wins) and mark resolved locally.
- **Cleanup policy**: Expose cleanup of old synced records in settings; make retention configurable.

### Architecture/UX
- **Routing**: Introduce `go_router` and move `StudentFormPage` behind named routes; keep `HomePage` as landing or remove if unused.
- **State**: Keep Provider; consider modularizing services behind interfaces to ease testing.
- **Theming/Fonts**: Add Hebrew fonts to `pubspec.yaml` (e.g., Rubik/Assistant) and wire into `HebrewTheme`.
- **Accessibility**: Add semantics labels, larger tap targets, and high-contrast checks for RTL.

### Testing & CI/CD
- **Unit tests**: 
  - `StudentRecord` logic (score calc, serialization)
  - `FormProvider` flows (init, update mode detection, save)
  - `LocalStorageService` DB lifecycle and sync status
- **Widget tests**: Hebrew text field with overlay, number picker selection, date picker rendering.
- **Service tests (mocked)**: `GoogleSheetsService` matching, insert position, fallback behaviors using `mockito`.
- **CI**: Add GitHub Actions to run `flutter format --set-exit-if-changed`, `flutter analyze`, and tests on PRs.

### Dependency hygiene
- **Run `flutter pub outdated`**: Plan safe upgrades (google_sign_in, googleapis, flutter_secure_storage, lints). Test sign‑in flows on Android/iOS after upgrades.
- **analysis_options**: Consider enabling stricter rules (e.g., `prefer_single_quotes`, `unnecessary_lambdas`, `always_declare_return_types`).

### Documentation
- **Setup guide**: Expand README with Google Console configuration, SHA‑1/256 steps, test user lists, and platform caveats.
- **Privacy**: Document data flow, scopes used (`spreadsheets`, `drive.file`), and user data ownership.
- **Release**: Add LICENSE and versioning/release notes template.

### Nice-to-have
- **Metrics/Logging**: Add optional structured logging with levels; consider Sentry/Crashlytics (opt‑in) for crash reports.
- **Export/Backup**: Allow CSV export from local DB; manual Google Sheets export instructions.

### Notes
- No existing files were modified; this document is a planning aid only.

