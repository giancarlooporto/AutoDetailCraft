# E2E Test Infra: AutoDetailCraft

## Test Philosophy
- Opaque-box, requirement-driven derived from `ORIGINAL_REQUEST.md` and `PROJECT.md`. No dependency on implementation internals.
- Methodology: Category-Partition + Boundary Value Analysis (BVA) + Pairwise Combinatorial Testing + Real-World Workload Testing.
- Target: 100% automated test pass, simulating browser refresh reload (Cmd+R / F5) across all core modules.

## Feature Inventory
| # | Feature | Source (requirement) | Tier 1 (>=5/feat) | Tier 2 (>=5/feat) | Tier 3 (Pairwise) | Tier 4 (Real-world) |
|---|---------|---------------------|:-----------------:|:-----------------:|:-----------------:|:-------------------:|
| 1 | Service Packages CRUD & Refresh | ORIGINAL_REQUEST R1 | 5 | 5 | ✓ | ✓ |
| 2 | My Garage Vehicles CRUD & Refresh | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ | ✓ |
| 3 | My Teams Staff & Schedule Linking | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ | ✓ |
| 4 | Inventory Items & Chemical Fill Levels | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ | ✓ |
| 5 | Calendar Operating Hours & Day Blocks | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ | ✓ |
| 6 | Client Booking Flow & Conflict Prevention | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ | ✓ |
| 7 | Feed Jobs, Discussions & Likes | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ | ✓ |

## Test Architecture
- **Test Runner**: Flutter Test Runner (`flutter test`)
- **Shared Test Core**:
  - `test/core/mock_http_client.dart`: Shared transparent PNG mock HTTP client to prevent network image exceptions in widget tests.
  - `test/core/test_harness.dart`: Standard test harness creating isolated sessions and providing `simulateBrowserRefresh(JobRepository repo)` via `SharedPreferences`.
- **Directory Layout**:
  - `test/tier1_unit/`: Model JSON serialization/deserialization, business logic calculations, ranking algorithms.
  - `test/tier2_widgets/`: Modal dialog form validations, interactive widgets, responsive component layouts.
  - `test/tier3_persistence/`: Dedicated browser refresh persistence suites for all 7 modules.
  - `test/tier4_e2e/`: Multi-module full user journeys (Studio setup -> Booking -> Schedule -> Execution).

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Complete Detailer Onboarding & Studio Setup | Service Packages, Teams, Inventory, Calendar Preferences | High |
| 2 | Customer Vehicle Booking & Availability Sync | Garage Vehicles, Calendar Day Blocks, Booking Flow, Slot Lockout | High |
| 3 | Multi-Tech Job Assignment & Capacity Booking | Teams Schedules, Calendar Preferences, Booking Flow | High |
| 4 | Studio Inventory Consumption & Fill Level Tracking | Inventory Chemicals, Dilution Dialog, Studio Recipes | Medium |
| 5 | End-to-End Feed Recipe Discussion & Social Engagement | Feed Custom Jobs, Comments Threads, Likes Counts | Medium |

## Coverage Thresholds
- Tier 1: ≥5 per feature (7 features × 5 = 35 test cases)
- Tier 2: ≥5 per feature (7 features × 5 = 35 test cases)
- Tier 3: pairwise coverage of major feature interactions (≥7 test cases)
- Tier 4: ≥5 realistic application scenarios
- **Total Minimum Test Cases**: ≥82 test cases across the new modular tiers + existing 65 tests = ≥147 total tests.
