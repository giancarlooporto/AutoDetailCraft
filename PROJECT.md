# Project: AutoDetailCraft Location Services & Explore Search

## Architecture
- **Framework & Runtime**: Flutter Web / Multi-platform (SDK ^3.13.2)
- **State Management**: Native Flutter `ChangeNotifier` + `ListenableBuilder` via central `JobRepository` singleton/provider pattern.
- **Location Architecture (Zero-Cost Browsing $0.00)**:
  - In-app Haversine distance calculation and sorting across `JobRepository.publicDetailers` using pure Dart (`dart:math`).
  - Zero billable Google API calls for casual Explore browsing and city/ZIP filtering.
  - Zero-hardware `LocationService` abstraction with deterministic test hooks.
- **Privacy & Dual-Address Architecture**:
  - `UserProfile` strictly segregates private residential client home address (`streetAddress`, `unitOrApt`, `city`, `state`, `postalCode`, `latitude`, `longitude`) from commercial shop studio address (`studioStreetAddress`, `studioUnitOrApt`, `studioCity`, `studioState`, `studioPostalCode`, `studioLatitude`, `studioLongitude`).
  - Activating detailer mode auto-inherits the client address if studio address is unset.
  - Updating the commercial studio address never mutates or overwrites the client's private residential address.
- **Navigation Architecture**:
  - `MapLauncherService` abstracts native Apple Maps (`maps://`) and Google Maps (`geo:` / `https://`) handoff via `url_launcher`, with mockable test hooks.
- **Persistence & Cloud Sync**:
  - Idempotent Supabase migration `20261102_add_location_fields.sql` extending `public.profiles` and `public.bookings`.
  - Local browser storage via `LocalStorageService` with backward-compatible model serialization.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | UserProfile Location Fields | Add `streetAddress`, `unitOrApt`, `city`, `state`, `postalCode`, `latitude`, `longitude` (and studio fields) with backward-compatible JSON | M1 | ORIGINAL_REQUEST R1 |
| 2 | BookingAppointment Location Fields | Retain `clientAddress`, add `clientUnitOrGateCode`, `latitude`, `longitude` | M1 | ORIGINAL_REQUEST R1 |
| 3 | Supabase Migration | Idempotent `20261102_add_location_fields.sql` adding location columns to `profiles` and `bookings` | M1 | ORIGINAL_REQUEST R1 |
| 4 | LocationService & Haversine | Device GPS retrieval (`geolocator`) + in-app Haversine formula distance calculation with mock provider | M1 | ORIGINAL_REQUEST R3 |
| 5 | Studio Address Auto-Carryover | Inherit client address upon detailer mode activation if studio address unset | M1 | ORIGINAL_REQUEST R2 |
| 6 | Studio Address Privacy Isolation | Editing commercial studio address does not mutate client private home address | M1 | ORIGINAL_REQUEST R2 |
| 7 | EditProfileDialog Inputs | Dedicated street, apt/gate, city, state, ZIP inputs with offline fallback | M1 | ORIGINAL_REQUEST R2 |
| 8 | Explore "Near Me" GPS Action | Explore search bar "📍 Near Me" button querying GPS and sorting studios | M2 | ORIGINAL_REQUEST R3 |
| 9 | Proximity Distance Badges | Display distance badges (e.g. "1.2 mi away") on studio feed cards | M2 | ORIGINAL_REQUEST R3 |
| 10 | Zero-Cost City/ZIP Search | Filter studios by city and ZIP code in-memory ($0.00 API cost) | M2 | ORIGINAL_REQUEST R3 |
| 11 | Checkout Service Location Card | Review step displays Service Location Card defaulting to pre-selected saved Home Address | M3 | ORIGINAL_REQUEST R4 |
| 12 | Checkout Temporary Location & Notes | Radio toggle to enter temporary address (work/gym) + gate code & parking notes | M3 | ORIGINAL_REQUEST R4 |
| 13 | Drop-Off Studio Directions | Drop-off services show studio physical address and directions button | M3 | ORIGINAL_REQUEST R4 |
| 14 | Native Navigation Handoff | "Navigate" button on appointment cards launching Apple/Google Maps via `MapLauncherService` | M3 | ORIGINAL_REQUEST R4 |
| 15 | Tier 1 Unit Test Suite | Comprehensive tests in `test/tier1_unit/` for serialization, inheritance, and Haversine | M4 | ORIGINAL_REQUEST R5 |
| 16 | Tier 2 Widget Test Suite | Comprehensive tests in `test/tier2_widgets/` for Explore search and checkout card | M4 | ORIGINAL_REQUEST R5 |
| 17 | Final System Verification | 100% test pass rate across all suites and `flutter analyze` 0 issues | M4 | ORIGINAL_REQUEST R5 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Data Models, Schema, Repository & Profile Dialog | Dependencies (`geolocator`, `url_launcher`), `UserProfile`, `BookingAppointment`, migration SQL, `LocationService`, detailer auto-carryover & isolation, `EditProfileDialog` | none | DONE (126 tier1 tests pass, 183 tier2 tests pass, 27 challenger stress tests pass, analyze 0 issues, Auditor CLEAN, Remediation complete) |
| M2 | Explore Search & "Near Me" GPS Proximity Sorting | Feed search bar "📍 Near Me" GPS action, Haversine proximity sorting, distance badges, zero-cost city/ZIP filtering | M1 | DONE (Feed screen & repo implemented, 12/12 stress tests pass, 9/9 zero cost tests pass, 578/578 workspace tests pass, analyze 0 issues, Auditor CLEAN) |
| M3 | Checkout Service Location Card & Navigation Handoff | Review step Service Location Card (saved home default + temporary toggle + gate notes), `MapLauncherService`, "Navigate" button on appointment cards | M1 | DONE (Implemented & verified across 4 viewports, 19/19 stress tests pass, Auditor CLEAN) |
| M4 | Automated Test Suites & End-to-End Verification | Tier 1 unit tests, Tier 2 widget tests, full workspace `flutter test` verification, `flutter analyze` 0 issues | M1, M2, M3 | DONE (All 644/644 workspace tests pass, `flutter analyze` 0 issues) |

## Interface Contracts
### `LocationService`
- `Future<LocationCoordinates?> getCurrentLocation()`
- `double calculateDistanceMiles(double lat1, double lon1, double lat2, double lon2)`
- `String formatDistance(double? miles)`
- `static void setMockLocationProvider(Future<LocationCoordinates?> Function()? provider)`

### `MapLauncherService`
- `Future<bool> launchNavigation({required double? latitude, required double? longitude, String? address})`
- `static void setMockLauncher(Future<bool> Function(String url)? launcher)`

### `JobRepository` ↔ UI Screens
- `Future<void> enableDetailerMode({UserRole? targetRole})`: Copies client address to studio address if `studioStreetAddress` or `studioCity` is empty.
- `Future<void> updateStudioAddress(...)`: Updates only studio location properties, preserving client home address.
- `Future<void> updateClientAddress(...)`: Updates only client home address.
- `Future<void> sortDetailersByProximity(double userLat, double userLon)`: Sorts `filteredDetailers` by distance and populates distance cache.
- `double? getDistanceToDetailer(String detailerId)`: Returns cached proximity distance in miles.

## Code Layout
- `lib/models/`:
  - `user_profile.dart`: Structured client & studio address fields, JSON converters, fallback getters.
  - `booking_models.dart`: `BookingAppointment` location and gate code fields.
- `lib/services/`:
  - `location_service.dart`: Device GPS and Haversine distance calculator.
  - `map_launcher_service.dart`: Native Apple/Google Maps launcher.
  - `job_repository.dart`: Proximity sorting, zero-cost search, studio address inheritance & isolation.
- `lib/screens/`:
  - `edit_profile_dialog.dart`: Structured address inputs with offline manual fallback.
  - `feed_screen.dart`: Explore search bar with "📍 Near Me" button and distance badges.
  - `booking_flow_screen.dart`: Review Step Service Location Card (saved home default, temporary toggle, gate notes).
  - `detailer_workbench_view.dart`: "Navigate" button on booking inspector.
  - `bookings_list_screen.dart`: "Navigate" button on client bookings.
- `supabase/migrations/`:
  - `20261102_add_location_fields.sql`: Idempotent schema extension for `profiles` and `bookings`.
- `test/`:
  - `test/tier1_unit/location_models_and_haversine_unit_test.dart`
  - `test/challenger/location_m1_stress_test.dart`
  - `test/challenger/address_privacy_and_role_switch_stress_test.dart`
  - `test/tier2_widgets/explore_location_search_and_near_me_test.dart`
  - `test/tier2_widgets/booking_checkout_location_selector_test.dart`
