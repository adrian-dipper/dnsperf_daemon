# Changelog

All notable changes to this project are tracked here.

This file has been reconstructed from the actual Git commit history (no Git tags yet). Release boundaries were inferred heuristically from feature clusters and merge points. It is recommended to add annotated tags (`git tag -a v0.x.y <commit>`) going forward.

Format (simplified Keep a Changelog): Added / Changed / Fixed / Docs / Removed / Security.

---
## Planned / Ideas
- Optional Prometheus exporter (HTTP metrics endpoint)
- Systemd unit / portable service variant
- Config validation command (`dns_perf_backend.sh --check-config`)
- Container image / minimal Alpine build
- Structured JSON log mode (toggle)
- Optional multi-metric export (min / max / p95 latency)

---
## [0.5.2] - 2025-10-05 (Improved Shutdown Handling)
### Fixed
- (e2a7168) Improved graceful shutdown handling for dnsperf process
  - Changed from pipe-based execution to background process with PID tracking
  - Added dedicated cleanup for active dnsperf process in `cleanup()` function
  - Implemented 5-second graceful shutdown timeout before force-killing dnsperf
  - dnsperf now runs in background with output captured to temporary file
  - Better signal handling: SIGTERM sent first, SIGKILL only if process doesn't exit
  - `DNSPERF_PID` variable tracks current running dnsperf process
  - Improved logging for dnsperf startup, graceful termination, and force-kill scenarios
  - Enhanced `wait` handling to detect if dnsperf was interrupted or failed
  - Cleanup of temporary dnsperf output files after test completion
  - Replaced PID array with single PID variable (only one dnsperf runs at a time)

_Notes:_ This release significantly improves daemon shutdown behavior, ensuring dnsperf processes are properly terminated when the daemon receives shutdown signals. The change from pipe-based to background execution allows for better process control and cleanup.

---
## [0.5.1] - 2025-10-05 (Bugfix: Random Sampling)
### Fixed
- (8340d57) Fixed random sampling returning zero domains due to faulty `--random-source` option
  - Removed broken `--random-source=<(echo $seed)` parameter from `shuf` command
  - The single-number seed output was insufficient for `shuf`'s random source, causing empty results
  - Now uses `shuf`'s default `/dev/urandom` source which works correctly
  - Resolves issue where logs showed "0 sampled daily" despite configured `RANDOM_SAMPLE_SIZE`

---
## [0.5.0] - 2025-10-05 (Random Domain Sampling)
### Added
- (419f591) Random sampling of daily hosts for variable test coverage
  - New `RANDOM_SAMPLE_SIZE` configuration parameter (default: 100)
  - Time-based seed (nanosecond precision) ensures unique sample selection per run
  - Load `DOMAIN_COUNT` domains, then randomly select `RANDOM_SAMPLE_SIZE` for testing
  - Setting to 0 uses all loaded domains (backward compatible)
- (db2fb1d) `shuf` dependency check added to installation script
- (6932b88, 020b556, c0ce88f) Smart configuration parameter migration in install script
  - Automatically detects and adds missing parameters to existing config files
  - Three-tier fallback strategy for parameter insertion (preferred position → section marker → end of file)
  - Order-independent parameter detection and insertion
  - Creates backup before modifying existing configuration
  - Works regardless of which parameters are present or missing

### Docs
- (b1e1c59) Documented `RANDOM_SAMPLE_SIZE` parameter in both README files (German and English)
- (b1e1c59) Added random sampling to features list
- (b1e1c59) Updated configuration examples with new parameter

_Notes:_ This release adds domain sampling capabilities while maintaining full backward compatibility. Existing installations will continue to work unchanged; the new parameter is optional.

---
## [0.4.0] - 2025-01-22 (History Storage Feature)
### Added
- (b1d8159) DNS performance history storage with configurable retention
- (b1d8159) New configuration parameter `HISTORY_RETENTION_DAYS` (default: 30 days)
- (b1d8159) Automatic cleanup of old history entries based on retention policy
- (b1d8159) History file `dns_perf_history.txt` with CSV format (timestamp,latency_ms)
- (b1d8159) Cross-platform date handling (GNU/Linux and BSD/macOS compatible)

### Changed
- (b1d8159) DNS test results now stored in both latest result file and historical log
- (b1d8159) Configuration reload (SIGHUP) now includes history retention parameter
- (b1d8159) Enhanced logging to include history management operations

### Fixed
- (b1d8159) Corrected shell script structure issues with local variables outside functions
- (b1d8159) Fixed broken if-else blocks in `run_dns_test()` function
- (b1d8159) Improved error handling in history management functions

### Docs
- (eb592e1) Update CHANGELOG.md for version 0.4.0 with history storage features

_Notes:_ Minor version bump for new feature addition. Backward compatible enhancement that adds persistent storage of DNS performance metrics over time without changing existing behavior.

---
## [0.3.3] - 2025-09-22 (Docs & CI Enhancements)
### Added
- (88e0a6b) feat: add changelog validation and contribution guidelines (CI workflow, contribution sections, enforcement script)
- (52e92bd) Merge pull request #1 from adrian-dipper/feature/changelog_enhancements_and_copilot_instructions

### Changed
- (41e03bf) ci(conventional): centralize commit type regex via scripts/conventional_commits.sh

### Fixed
- (b42491b) fix: broken formatting
- (5f7a022) fix: improve commit message validation logic in changelog_and_commits.yml
- (25bfdc4) fix: enhance commit message validation regex in changelog_and_commits.yml
- (f034142) ci: fix subshell issue in conventional commits validation loop (preserve INVALID state)
- (6a27fe2) fix(script): initialize HAVE_CHANGELOG_CHANGE to avoid unbound variable under set -u

### Docs
- (e076daf) docs(changelog): record centralized commit regex change and docs reference under 0.3.3
- (8a0e84a) docs: update CHANGELOG.md for version 0.3.3 with CI and documentation enhancements
- (d9288d8) docs: add detailed changelog update policy and validation reminders to Copilot instructions
- (15a343f) docs: add Copilot instructions for conventional commit messages
- (bc02553) docs: update CHANGELOG.md
- (a37e9a6) docs: update README to clarify MIT license details and add motivational note
- (6b86997) docs: update CHANGELOG version 0.3.3 section with recent validation fix commits
- (af34661) docs(changelog): consolidate latest commits into 0.3.3 section (no new release)
- (0c0cacb) docs(readme): document [skip-conventional-check] directive in contribution guidelines
- (2efce38) docs(contribution): reference centralized conventional commit regex script
- (4d32847) docs(changelog): add HAVE_CHANGELOG_CHANGE init fix to 0.3.3 fixed section

_Notes:_ Non-functional release focusing on policy, documentation, and CI/CD guardrails. Runtime behavior unchanged.

---
## [0.3.2] - 2025-09-22 (Changelog & Preamble Alignment)
### Docs
- (340d348) Introduce `CHANGELOG.md` and link from both READMEs
- (3af4721) Align / unify README preambles (merge `feature/readme_preambel`)

_Notes:_ Purely documentation-focused release adding formal change tracking and ensuring bilingual README parity. No runtime behavior changes.

---
## [0.3.1] - 2025-09-21 (Documentation & Presentation Refresh)
### Docs
- (dc43731) Enhance README disclaimer and feature clarity
- (78f4f8a) Add English README with bilingual navigation
- (95fc87f) Introduce overengineering disclaimer & AI-generated code notice
- (ad5554d) Clarify average latency precision (six decimals)
- (d1ee820) Correct unit clarification (seconds vs ms)

_Rationale:_ Purely documentation / presentation improvements after introducing advanced process control (0.3.0).

---
## [0.3.0] - 2025-09-21 (Process Supervision & Robust Reload)
### Added
- (ad3314a) Interruptible, signal-aware sleep + graceful shutdown enhancements
- (1cc9720) Child process supervision & forced termination (dnsperf, wget, unzip, etc.)

### Fixed
- (853badc) Reload logic now rebuilds host list and updates derived file paths

### Changed
- (1cc9720) Refined termination sequence & logging around process lifecycle

### Docs
- (ba2bb70) Merge branch `fix/rc_restart_and_reload_not_working_correctly`

_Notes:_ This cluster hardens runtime resilience and ensures SIGHUP-driven reloads produce accurate host metrics.

---
## [0.2.0] - 2025-09-21 (Testing Infrastructure & Service Improvements)
### Added
- (407cf05) Backend testing harness + Makefile integration (`make test`)
- (5a0bb7e) Improved test file count logic
- (f9d0e69) Stop timeout in init script for graceful shutdown window
- (bad11d6) Reload command in OpenRC script
- (999ceb0) Clarify QUERIES_PER_SECOND description in config
- (a464162) LICENSE (MIT) + README license section
- (4f8fdab) Makefile for install / lifecycle convenience
- (9a993f2) Initial external configuration file support
- (8bc3d49, eae6d56) Shellcheck directives for config sourcing
- (715acfc) Added logging to `wget` and `unzip`

### Changed
- (68b112e) Logging refactor: centralized output to log file
- (93a1084) Streamlined date handling in host update
- (1f87e49) Logging function readability & format consistency
- (a7eab3b) Persist only latest result value; doc interval alignment
- (6141ca3) Reduce sleep to 30s and improve timing logic
- (3e1e249) Rename scripts for clarity
- (2f675bb) Refactor for OpenRC compatibility & result handling improvements

### Docs
- (5636772) Expanded README (features, installation, troubleshooting)
- (9cfe18d) Update installation instructions
- (bbb45a3) Default DNS server to Cloudflare + tidy static hosts
- (3d7c75e, 22b0348, ec7459a) Installation script enhancements (migration, backups, path management)
- (4abbe50) Add `.gitignore`

_Notes:_ Foundation for a maintainable operational loop: external config, improved logging, test harness, structured install.

---
## [0.1.0] - 2025-09-21 (Initial Foundation)
### Added
- (c615383) Initial repository skeleton
- (8055fe5) Introduce DNS Performance Daemon core script & install scaffolding
- (2f675bb precursor) Early OpenRC baseline & result logic

_Notes:_ Minimal functional daemon measuring DNS latency with static + downloaded domain handling groundwork.

---
## Integrity & Reconstruction Notes
- All commits reconstructed from Git history spanning 2025-09-21 to 2025-01-22
- No semantic version tags existed at reconstruction time; versions inferred from commit clusters
- Some commits touch multiple areas; listed under most significant impact area
- Short hashes shown; use `git show <hash>` for detail
- Development branches tracked separately to maintain release clarity

## Conventions
- **Added**: new feature or capability
- **Changed**: behavior / interface / refactor impacting operation
- **Fixed**: correction of faulty behavior
- **Docs**: documentation-only change
- **Removed**: feature eliminated
- **Security**: security-relevant fix or hardening

---
Generated from comprehensive Git commit history analysis; manual curation for release boundaries.
