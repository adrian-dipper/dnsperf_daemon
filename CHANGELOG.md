# Changelog

All notable changes to this project are tracked here.

This file has been reconstructed from the actual Git commit history (no Git tags yet). Release boundaries were inferred heuristically from feature clusters and merge points. It is recommended to add annotated tags (`git tag -a v0.x.y <commit>`) going forward.

Format (simplified Keep a Changelog): Added / Changed / Fixed / Docs / Removed / Security.

## [Unreleased]
### Planned / Ideas
- Optional Prometheus exporter (HTTP metrics endpoint)
- Systemd unit / portable service variant
- Config validation command (`dns_perf_backend.sh --check-config`)
- Optional historical ring buffer (configurable length)
- Container image / minimal Alpine build
- Structured JSON log mode (toggle)
- Optional multi-metric export (min / max / p95 latency)

---
## [0.3.3] - 2025-09-22 (Docs & CI Enhancements)
### Added
- (88e0a6b) feat: add changelog validation and contribution guidelines (CI workflow, contribution sections, enforcement script)

### Fixed
- (5f7a022) fix: improve commit message validation logic in changelog_and_commits.yml
- (25bfdc4) fix: enhance commit message validation regex in changelog_and_commits.yml
- (f034142) ci: fix subshell issue in conventional commits validation loop (preserve INVALID state)

### Docs
- (8a0e84a) docs: update CHANGELOG.md for version 0.3.3 with CI and documentation enhancements
- (d9288d8) docs: add detailed changelog update policy and validation reminders to Copilot instructions
- (15a343f) docs: add Copilot instructions for conventional commit messages
- (bc02553) docs: update CHANGELOG.md
- (a37e9a6) docs: update README to clarify MIT license details and add motivational note
- (6b86997) docs: update CHANGELOG version 0.3.3 section with recent validation fix commits
- (0c0cacb) docs(readme): document [skip-conventional-check] directive in contribution guidelines

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
- (853badc0) Reload logic now rebuilds host list and updates derived file paths

### Changed
- (1cc9720) Refined termination sequence & logging around process lifecycle

### Docs
- (ba2bb707) Merge branch `fix/rc_restart_and_reload_not_working_correctly`

_Notes:_ This cluster hardens runtime resilience and ensures SIGHUP-driven reloads produce accurate host metrics.

---
## [0.2.0] - 2025-09-21 (Testing Infrastructure & Service Improvements)
### Added
- (407cf057) Backend testing harness + Makefile integration (`make test`)
- (5a0bb7e6) Improved test file count logic
- (f9d0e69a) Stop timeout in init script for graceful shutdown window
- (bad11d66) Reload command in OpenRC script
- (999ceb00) Clarify QUERIES_PER_SECOND description in config
- (a4641620) LICENSE (MIT) + README license section
- (4f8fdab7) Makefile for install / lifecycle convenience
- (9a993f29) Initial external configuration file support
- (8bc3d49a, eae6d56a) Shellcheck directives for config sourcing
- (715acfc0) Added logging to `wget` and `unzip`

### Changed
- (68b112e3) Logging refactor: centralized output to log file
- (93a10846) Streamlined date handling in host update
- (1f87e494) Logging function readability & format consistency
- (a7eab3b1) Persist only latest result value; doc interval alignment
- (6141ca37) Reduce sleep to 30s and improve timing logic
- (3e1e2497) Rename scripts for clarity
- (2f675bbe) Refactor for OpenRC compatibility & result handling improvements

### Docs
- (56367724) Expanded README (features, installation, troubleshooting)
- (9cfe18db) Update installation instructions
- (bbb45a34) Default DNS server to Cloudflare + tidy static hosts
- (3d7c75ee, 22b03482, ec7459a1) Installation script enhancements (migration, backups, path management)
- (4abbe509) Add `.gitignore`

_Notes:_ Foundation for a maintainable operational loop: external config, improved logging, test harness, structured install.

---
## [0.1.0] - 2025-09-21 (Initial Foundation)
### Added
- (c615383d) Initial repository skeleton
- (8055fe59) Introduce DNS Performance Daemon core script & install scaffolding
- (2f675bbe precursor) Early OpenRC baseline & result logic

_Notes:_ Minimal functional daemon measuring DNS latency with static + downloaded domain handling groundwork.

---
## Integrity & Reconstruction Notes
- All commits are from 2025-09-21 to 2025-09-22; grouped logically.
- No semantic version tags existed at reconstruction time; versions inferred.
- Some commits touch multiple areas; they are listed under the most significant impact area.
- Short hashes shown; use `git show <hash>` for detail.

## Conventions
- Added: new feature or capability
- Changed: behavior / interface / refactor impacting operation
- Fixed: correction of faulty behavior
- Docs: documentation-only change
- Removed: feature eliminated
- Security: security-relevant fix or hardening

## Next Steps (Suggestion)
1. Tag current state: `git tag -a v0.3.3 -m "Docs & CI enhancements" d9288d8`
2. Optionally backfill tags for earlier inferred releases (0.3.2, 0.3.1, 0.3.0, 0.2.0, 0.1.0)
3. Automate future changelog updates via a lightweight script parsing `git log` since last tag
4. Consider adopting Conventional Commits for clearer automated grouping

---
Generated largely via iterative AI-assisted development; manual curation minimal.
