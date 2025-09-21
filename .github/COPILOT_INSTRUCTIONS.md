# Copilot Instructions: Conventional Commit Messages

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

Thank you.
