# Copilot Instructions: Conventional Commit Messages

## CRITICAL: NO AUTOMATIC COMMITS
**NEVER** create commits, stage files, or run `git commit` commands unless the user explicitly asks you to commit.
- When making file changes, ONLY edit the files — do not automatically commit them.
- After completing requested changes, inform the user that files have been modified and await their explicit instruction to commit.
- If the user asks you to "commit" or "create a commit", only then proceed with staging and committing.
- Exception: If the user says phrases like "commit this" or "make a commit with message X", then you may proceed.

Copilot, when suggesting commit messages, adhere strictly to the Conventional Commits style:

Format:
```
<type>(optional-scope)!: <short imperative description>

<optional body explaining WHAT and WHY (not HOW)>

<optional footer>
```

Allowed <type> values:
- feat: A new user-facing feature
- fix: A bug fix
- docs: Documentation changes only
- style: Formatting / whitespace / stylistic changes (no logic impact)
- refactor: Code restructuring without changing behavior
- perf: Performance improvement
- test: Adding or adjusting tests only
- build: Build system or dependency changes
- ci: Continuous Integration related changes
- chore: Routine maintenance (infrastructure / tooling)
- revert: Reverts a previous commit
- security: Security-related change / hardening

Guidelines:
- Use lowercase commit types.
- Description: start with a verb in imperative form, no trailing period.
- Keep summary line ≤ 72 characters where practical.
- If the change introduces a breaking change, append `!` after type/scope and include a `BREAKING CHANGE:` footer explaining it.
- Reference issues in the footer (e.g. `Refs #12` or `Fixes #34`).
- For multi-line body: separate from header by one blank line.
- Avoid past tense ("added", "fixed"). Prefer imperative ("add", "fix").

Examples:
```
feat: add process supervision with forced termination timeout
fix(config): rebuild host list after reload to reflect new static hosts
docs(readme): add bilingual changelog reference
refactor(logging): simplify multiline handler indentation logic
perf: reduce unnecessary list rebuilding in update cycle
ci: add changelog presence verification to PR workflow
revert: revert feat: add experimental metrics exporter
```

Non-compliant suggestions should be adjusted automatically before finalizing.

Special Overrides:
- Commits containing ONLY merges can keep default merge headers.
- To intentionally skip changelog update, include `[skip-changelog]` in body (use sparingly; still discouraged) — this will signal CI to allow omission.

### Bilingual Documentation Rule
Whenever a change affects one primary documentation file (`README.md` or `README.en.md`):
- Mirror the intent in the counterpart file in the same pull request.
- If a change intentionally applies to only one language (rare), explicitly note rationale in the commit body and add `docs(readme):` prefix.
- Preferred sync commit style:
  - `docs(readme): sync English and German contribution sections`
  - `docs(readme): update latency description (de/en)`
- CI may be extended to warn if one README changes without the other.
- Do NOT use `[skip-changelog]` for cross-language documentation alignment unless absolutely no semantic meaning changed (pure whitespace / link anchor fix).

Recommended workflow:
1. Edit the primary README.
2. Propagate identical structural or semantic change to the other language.
3. Re-read both for consistency (feature list order, sections present, same examples adapted linguistically).

If Copilot proposes a commit touching only one README, suggest also generating the mirrored diff before finalizing.

### Changelog Update Policy (Use git log)
When assisting with CHANGELOG updates, ALWAYS derive entries from the actual Git history — never invent hashes or reorder commits arbitrarily.

**IMPORTANT: Always use specific version numbers — NEVER use `[Unreleased]` section headers.**
- Every changelog entry must have a concrete version number (e.g. `[0.3.4]`, `[1.0.0]`).
- If the next version number is not yet known, ask the user what version number to use.
- Do not create or maintain an `[Unreleased]` section at the top of the changelog.

Required procedure:
1. Identify last released version header in `CHANGELOG.md` (e.g. `## [0.3.3]`); if none, treat all commits as initial release.
2. Collect new commits since that version using one of:
   - `git log --oneline <last_version_commit_hash>..HEAD`
   - If commit hash unknown, parse the short hashes already present in the previous version section and use the earliest as boundary.
3. For each new commit:
   - Extract short hash (first 7 chars) and subject line.
   - Map subject to category by its Conventional Commit type (`feat`→Added, `fix`→Fixed, `docs`→Docs, `refactor`/`perf`→Changed, `security`→Security, others default → Changed / Added contextually).
4. Create (or update) a new version block ABOVE the previous top version in descending order.
5. Use the existing format:
   ```
   ## [X.Y.Z] - YYYY-MM-DD (Short Title)
   ### Added / Changed / Fixed / Docs / Security / Removed (only if entries exist)
   - (abc1234) subject line...
   ```
6. **ALWAYS use a specific version number (X.Y.Z).** Never use `[Unreleased]` or `(unreleased)` annotations.
7. Do NOT duplicate a commit already listed; skip merges unless they carry unique semantic changes.
8. Keep line wrapping consistent; avoid trailing spaces.
9. Preserve existing explanatory _Notes:_ block style.

Validation reminders:
- Ensure every non-doc, non-ci code change (unless `[skip-changelog]`) appears in a section.
- If only Docs changes: may place all under `### Docs` of new patch release or fold into existing Unreleased block.
- Do not collapse different types into a single catch-all unless empty.

Example categorization mapping:
- `feat(auth): ...` → Added
- `fix(cache): ...` → Fixed
- `docs(readme): ...` → Docs
- `refactor(core): ...` → Changed
- `perf(resolver): ...` → Changed (mention optimization)
- `security(crypto): ...` → Security
- `revert: revert feat: ...` → Changed (or its own Revert section if multiple)

If an instruction requests a Changelog update without showing recent commits, first request or retrieve `git log` output before proceeding.

Thank you.
