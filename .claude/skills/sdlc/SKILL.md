---
name: sdlc
description: >-
  Take a change to the devops-image repo from idea to published image: plan, branch, make the change, run the
  right local checks for its size, propose and make the commit, open the PR, watch CI, rebase-merge, confirm
  GHCR published :latest and :<sha8>, then clean up. Use it whenever the user wants to fix, bump, add or change
  anything in this repo and get it shipped or released, or asks to "push and open a PR", "merge once CI passes",
  "release this", "check it published", or to resume any of those steps part-way, even if they don't say
  "release".
---

# Change lifecycle for devops-image

A merge to `main` is the release: `main.yml` builds the base, gcp and aws images for amd64 and arm64, scans
each amd64 digest with Trivy, and only then tags `:latest` and `:<sha8>` in GHCR. There are no git tags or
GitHub Releases. So "releasing" means getting a change safely through that pipeline and confirming it came out
the other end.

Read `AGENTS.md` first and follow it; this skill sequences the work, AGENTS.md has the rules (disk space, which
checks a change needs, when CI runs). The user's global CLAUDE.md applies too: propose before branching,
staging or committing, and confirm before deleting anything.

Start wherever the user is. If they've already got a branch or an open PR, pick up at that step; run the
earlier ones only to check state (`git status -sb`, `gh pr list`). Track the steps you'll do in the todo list.

## 1. Look before you plan

- `git status -sb`, `git fetch origin`, and `gh pr list` to see the branch, uncommitted work and open PRs.
- `df -h /` and report the number. Under 10 GB free, don't run anything that uses Docker; say so and ask.
- Write a short plan in `.plans/<topic>.md` (goal, approach, steps, checks, branch, commit message) and give
  the user the path. For a one-line bump, two lines of plan are enough.

## 2. Branch

- Branch from `origin/main`, not from whatever is checked out: `git switch -c type/short-description origin/main`.
  Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.
- If an open PR touches the same files, say so; the user may want to wait for it to merge first.

## 3. Make the change

Minimal change for the stated goal. If a new file becomes an image input (copied into the build), add it to
both `paths:` lists in `main.yml`.

## 4. Pick and run the checks

Classify the change with AGENTS.md's "Local checks" section, then run what it calls for. In short:

| Change | Run |
| --- | --- |
| Docs, version bumps, small edits | `task lint` |
| Workflow edits | `task lint`; `act` for the edited workflow (`task ci:local` for `main.yml`'s verify job, `act push -W .github/workflows/lint.yml -j lint` for lint) |
| Major refactor (layers moved, user/shell setup, `verify-installation.sh` logic, build scripts) | `task lint`, `task test:ci`, then `task ci:local` |

Things that went wrong before and why:

- Check `df -h /` again before each Docker step; builds keep growing. A base build is about 4-5 GB, and an
  act run adds a buildx builder with its own cache.
- Run one act job at a time and nothing else act-related alongside it (not even `act -n`): act reuses fixed
  container names, and a second invocation killed the first one's container mid-run.
- Never build or `docker pull` the full gcp/aws images locally; CI builds them. To inspect a published image,
  read it from the registry (`docker buildx imagetools inspect`, or Trivy with `--image-src remote`).
- A bug fix comes with a regression check, normally in `scripts/verify-installation.sh`. Show it fails
  without the fix (a negative test against the built image is enough), not only that it passes with it.

Say which checks you ran and which you skipped, and why.

## 5. Docs, then the commit proposal

If logic, architecture or configuration changed, propose the README / AGENTS.md updates once, here.

Then propose, in one message, and wait for approval:

- **Branch** and **files to stage** (by name; never `git add .`, never `--no-verify`).
- **Message**: Conventional Commits, lowercase, concise.
- **Checks**: what ran and passed, what was skipped.
- What CI will do with it: whether the change touches an image input (`Dockerfile`, `.dockerignore`,
  `aqua.yaml`, `scripts/**`, `main.yml`, `.github/actions/**`), so the PR runs the image build, or only lint.
- Cleanup you'd like to do afterwards, with exact paths and sizes.

Leave `.plans/` out of commits; it's untracked on purpose.

## 6. Push and open the PR

`git push -u origin <branch>`, then `gh pr create --base main` with a body that covers: what changed and why,
how it was tested locally (and what wasn't), and anything a reviewer should know about CI for this change.

## 7. Watch CI

- `gh pr checks <n>` for a snapshot. To wait, start `gh run watch <run-id> --exit-status` in the background
  (one per run) rather than polling, and report when it finishes.
- What's normal on a PR: the four `build` jobs only fill the build cache (about 20 s when cached), `publish` is
  skipped, and the digest scan in `build` doesn't run; it only runs on main. The `Trivy` code-scanning check can
  say "skipping" because main has gcp/aws scan results a PR never uploads. The base-image scan and its
  CRITICAL gate in `verify` are the PR's real scan.
- On failure, read `gh run view <run-id> --log-failed`, explain it, and fix it on the branch if it's yours to
  fix. Don't merge.

## 8. Merge

Only when the user has asked for it (now, or earlier as "merge once CI passes"), and only after the PR's
checks pass.

- `gh pr merge <n> --rebase --delete-branch`. This keeps history linear and deletes the branch on GitHub and
  locally, switching your checkout to an up-to-date `main`.
- Another open PR that was cut before this merge doesn't have its changes. Offer to rebase it onto `main` and
  `git push --force-with-lease`; do it only when asked.

## 9. Confirm it published

- Find the main run for the merge commit (`gh run list --branch main --workflow main.yml -L 3`) and watch it.
  Every job should pass: `verify`, the four `build` jobs (the amd64 ones scan their digest and gate on fixable
  CRITICALs), and both `publish` jobs. A failed gate stops `publish`, so `:latest` stays on the last good image;
  report the finding from the job summary.
- Then run `.claude/skills/sdlc/scripts/check-published.sh` (default `origin/main`; pass a commit to check
  another). It reads the registry only and confirms, for each image, that `:<sha8>` exists, is amd64 + arm64,
  and that `:latest` is the same index.

## 10. Clean up

Ask first, listing exact names and sizes, then remove only what this work created:

- Local images from `task test:ci` / act: `devops-base`, `base-image`; dangling images (`docker images -f
  dangling=true`).
- Build cache (`docker system df`; `docker builder prune -f`) and an act buildx builder container plus its
  `_state` volume, if one was left behind.
- `.tmp/` files you created (logs, scan output). Leave older `.tmp/` files alone.

Report `df -h /` before and after.

## Report

Finish with: the PR link and state, the main run result, the `check-published.sh` output, what was cleaned up,
and anything left for the user (other open PRs, follow-ups found along the way).
