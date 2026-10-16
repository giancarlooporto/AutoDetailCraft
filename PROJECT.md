# Project: AutoDetailCraft Functional Audit, Persistence Hardening & Testing

## Architecture
- **Framework & Runtime**: Flutter Web (SDK ^3.13.2)
- **State Management**: Native Flutter `ChangeNotifier` + `ListenableBuilder` via central `JobRepository` singleton/provider pattern.
- **Persistence Layer**:
  - Local browser storage: `LocalStorageService` utilizing `SharedPreferences` (HTML5 `window.localStorage` on Web).
  - Cloud database & auth: `SupabaseDbService` & `SupabaseAuthService` (`supabase_flutter: ^2.17.2`).
  - Media CDN: Cloudflare R2 via `R2StorageService`.
- **Hydration & Synchronization**:
  - Offline-first / local-first architecture.
  - Initial load executes a single re-entrancy protected `JobRepository.init()` pass reading dedicated entity keys from `LocalStorageService`.
  - Cloud hydration (`_refreshProfileFromCloud`) non-destructively merges server state without overwriting local custom packages/vehicles when cloud returns empty or null.
  - Guest/Detailer state distinction: Guest mode does not lock users out of their local studio packages, garage vehicles, or bookings.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Single-pass initialization lock | Remove un-awaited `init()` from constructor; prevent double init race in `main.dart` | M1 | Survey 1 (O1) |
| 2 | Dedicated entity storage keys | Add dedicated storage keys (`adc_service_packages_v1`, etc.) in `LocalStorageService` | M1 | Survey 1 (O3, Concl) |
| 3 | Service Packages CRUD & Refresh | Add, update, delete custom packages; survive browser reload; non-destructive cloud merge | M1 | ORIGINAL_REQUEST R1 |
| 4 | Studio guest mode lockout fix | Ensure local studio workbench and garage do not get locked behind guest view on reload | M1 | Survey 1 (O2) |
| 5 | My Garage Vehicles CRUD & Refresh | Add, update, delete vehicles; survive reload; preserve photo URLs | M2 | ORIGINAL_REQUEST R2 |
| 6 | My Teams Staff & Shifts Persistence | Add/edit/remove staff; persist `customWeeklySchedule` and personal shifts on reload | M2 | ORIGINAL_REQUEST R2 |
| 7 | Inventory Items & Chemical Fill Levels | Add/edit/delete hardware, chemicals, recipes; persist fill status (Full/Half/Empty) & dilution specs | M3 | ORIGINAL_REQUEST R2 |
| 8 | Calendar Operating Hours & Day Blocks | Persist weekly hours, day blocks, and custom slots; sync with booking modal | M3 | ORIGINAL_REQUEST R2 |
| 9 | Client Booking Flow & Conflict Prevention | Lock out booked slots, prevent double-bookings, persist appointments in client & detailer views | M3 | ORIGINAL_REQUEST R2 |
| 10 | Feed Community Jobs, Comments & Likes | Persist custom job uploads, discussion comments on all jobs (including mock jobs), and like counts | M4 | ORIGINAL_REQUEST R2 |
| 11 | Mobile 390px RenderFlex Overflow Fixes | Fix docked bars & specialist rows in `PublicStudioScreen`, `BookingFlowScreen`, `JobDetailScreen` | M4 | ORIGINAL_REQUEST R3, Survey 2 |
| 12 | UI/UX Usability Polish & Feedback | Enrich empty states (Studio Service Inspector), form validation feedback, action snackbars | M4 | ORIGINAL_REQUEST R3, Survey 2 |
| 13 | Modular 4-Tier Test Suite & TestHarness | Build reusable `TestHarness` with refresh simulation, Tier 1 unit, Tier 2 widget, Tier 3 persistence, Tier 4 E2E | E2E Testing Track | ORIGINAL_REQUEST R4, Survey 3 |
| 14 | Final Verification & Adversarial Shield | 100% passing E2E tests across all tiers, 0 flutter analyze issues, Phase 2 adversarial coverage hardening | M5 | ORIGINAL_REQUEST R4, Pattern |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Services & Core Persistence Hardening | Initialization lock, dedicated storage keys, Service Packages CRUD & refresh survival, non-destructive cloud merge, guest mode unlock | none | DONE (132 tests pass, analyze 0 issues, Auditor CLEAN, 2 Reviewers & 2 Challengers APPROVE) |
| M2 | Garage & Teams Multi-Module Hardening | My Garage vehicles CRUD & refresh, My Teams staff & weekly schedule persistence, R2 photo preservation | M1 | DONE (155 tests pass, analyze 0 issues, Auditor CLEAN, 2 Reviewers & 2 Challengers APPROVE) |
| M3 | Inventory, Calendar & Booking Flow Hardening | Inventory items (hardware, chemicals, recipes, fill status), Calendar preferences & day blocks, Client booking slot lockouts & appointment persistence | M1 | DONE (197 tests pass, analyze 0 issues, Auditor CLEAN, 2 Reviewers & 2 Challengers APPROVE) |
| M4 | Feed, Community & Responsive UI/UX Polish | Feed custom jobs, comments & likes persistence, Mobile 390px RenderFlex overflow fixes, empty states & action snackbars | M2, M3 | IN_PROGRESS (Remediating M4-DEFECT-01 PublicStudioScreen Card Duration Overflow: Iteration 3) |
| M5 | Final E2E Regression Shield & Adversarial Hardening | Phase 1: Pass 100% of E2E tests (Tiers 1-4). Phase 2: Adversarial coverage hardening (Tier 5) with Challengers & Reviewers | M4, E2E Testing Track (TEST_READY.md) | PLANNED |

## Parallel Track: E2E Testing Track
- **Scope**: Build `test/core/test_harness.dart` with browser refresh simulation, Tier 1 unit tests (`test/tier1_unit/`), Tier 2 widget tests (`test/tier2_widgets/`), Tier 3 persistence tests (`test/tier3_persistence/`), Tier 4 E2E user journeys (`test/tier4_e2e/`), and publish `TEST_READY.md`.
- **Dependencies**: none (derived from user requirements and specifications independently).
- **Status**: IN_PROGRESS.

## Interface Contracts
### `LocalStorageService` ↔ `JobRepository`
- `Future<void> saveServicePackages(List<ServicePackage> packages)`
- `Future<List<ServicePackage>> loadServicePackages()`
- `Future<void> saveGarageVehicles(List<UserVehicle> vehicles)`
- `Future<List<UserVehicle>> loadGarageVehicles()`
- `Future<void> saveTeamMembers(List<TeamMember> members)`
- `Future<List<TeamMember>> loadTeamMembers()`
- `Future<void> saveInventoryItems(List<InventoryItem> items)`
- `Future<List<InventoryItem>> loadInventoryItems()`
- `Future<void> saveCalendarBlocks(List<CalendarAvailabilityBlock> blocks)`
- `Future<List<CalendarAvailabilityBlock>> loadCalendarBlocks()`
- `Future<void> saveDetailerCalendarPreferences(DetailerCalendarPreferences prefs, {String? detailerId})`
- `Future<DetailerCalendarPreferences?> loadDetailerCalendarPreferences({String? detailerId})`
- `Future<void> saveBookings(List<BookingAppointment> bookings)`
- `Future<List<BookingAppointment>> loadBookings()`
- `Future<void> saveJobCommentsOverride(String jobId, List<JobComment> comments)`
- `Future<Map<String, List<JobComment>>> loadJobCommentsOverrides()`

### `SupabaseDbService` ↔ `JobRepository`
- `fetchUserProfile(String userId)` must return existing remote packages if present; if empty or null, return null (do NOT fall back to `MockDataService.standardPackages` inside the fetcher).
- `JobRepository._refreshProfileFromCloud()` must preserve local custom packages and vehicles when remote tables are empty or unconfigured.

### UI Screens ↔ `JobRepository`
- `ProfileScreen`: If `workbenchMode == 'studio'` or custom packages/workbench items exist, render `DetailerWorkbenchView` directly without forcing unauthenticated guest blocking.
- `BookingsListScreen`: If local or cloud bookings exist, render the bookings list with status tabs rather than blocking behind guest view.

## Code Layout
- `lib/models/`: Entity definitions with JSON serialization (`booking_models.dart`, `user_vehicle.dart`, `team_member.dart`, `inventory_item.dart`, `calendar_availability_block.dart`, `detail_job.dart`, `user_profile.dart`).
- `lib/services/`: State management and I/O (`job_repository.dart`, `local_storage_service.dart`, `supabase_db_service.dart`, `supabase_auth_service.dart`, `r2_storage_service.dart`).
- `lib/screens/`: UI screens and responsive views (`detailer_workbench_view.dart`, `public_studio_screen.dart`, `booking_flow_screen.dart`, `bookings_list_screen.dart`, `job_detail_screen.dart`, `profile_screen.dart`, `feed_screen.dart`).
- `lib/widgets/`: Modal dialogs and reusable components (`service_package_editor_dialog.dart`, `vehicle_editor_dialog.dart`, `add_team_member_dialog.dart`, `inventory_item_editor_dialog.dart`, `calendar_preferences_dialog.dart`).
- `test/`:
  - `test/core/`: `mock_http_client.dart`, `test_harness.dart`.
  - `test/tier1_unit/`: Models serialization, calculations, algorithms.
  - `test/tier2_widgets/`: Dialog and component widget tests.
  - `test/tier3_persistence/`: Persistence and refresh simulation tests for all 7 modules.
  - `test/tier4_e2e/`: End-to-end multi-module user flows.
