# Public documentation implementation plan

> Execute inline in the current conversation using executing-plans; preserve existing unpublished edits.

**Goal:** Make StarMemo's public introduction concise and consistent with the released implementation.

**Architecture:** Keep the App/Core/UI/Vendor boundaries and all runtime behavior unchanged. Separate user documentation from development and verification records.

**Tech Stack:** Markdown documentation; Swift Package Manager manifests and Swift source as evidence; Git and GitHub CLI for repository checks.

## Constraints

- No functional changes, version bump, release upload, or history rewrite. Follow-up user approval permits a documentation-only commit and synchronization to GitHub and AtomGit.
- Do not publish pending 0.1.10/0.1.11 changes as released features.
- Preserve MIT and third-party attribution, unsigned-package and unencrypted-storage warnings.
- User approved making BusyStudyingWu/StarMemo public; inspect tracked history first, stop on actual secrets.

## Tasks

- [x] Inspect module dependencies, editor entry point, session restoration and global settings; record structural follow-ups without refactoring.
- [x] Scan reachable Git history for common secret patterns, sensitive filenames and personal paths; output filenames/counts only, not secret values.
- [x] Rewrite README.md for users; correct docs/ARCHITECTURE.md and simplify docs/USAGE.md and CONTRIBUTING.md. Remove stale private-repository wording from SECURITY.md.
- [x] Replace personal absolute paths in the two historical plan documents with repository-relative descriptions. Do not rewrite history.
- [x] Check local Markdown links and git diff whitespace, inspect exact changed file scope, and record audit limits in docs/PUBLIC-REVIEW.md.
- [x] After checks, change GitHub visibility using gh repo edit and verify with gh repo view. Documentation was initially left uncommitted for review; synchronization requires the user's follow-up approval.
