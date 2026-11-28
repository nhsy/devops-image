# Agent notes

## Low disk space

The development machine's root volume is small and often over 90% full. A full image build fills it, and Docker
then fails with `no space left on device` part way through.

- Always check free space with `df -h /` before running anything that uses Docker (a build, a pull, an act run,
  `task test:*`, `task ci:*`), and report the number. If less than 10 GB is free, don't run it: say so and ask.
  Builds keep growing while they run, so check again before starting the next step of a sequence.
- Don't run anything that builds or pulls the full images locally:
  - `task build:gcp`, `task build:aws`, `task build:all`
  - `task test:gcp`, `task test:aws`, `task test:all` (they need those images)
  - `docker build` / `docker pull` of large images
- Let the pull request's CI do the full multi-platform builds instead. Under act the image build jobs are skipped
  (`.actrc` passes `.github/act-event.json`), so `act` only ever runs the verify and lint jobs.
- Never delete Docker images, volumes or build cache to make room without asking first.

## Local checks before a commit

This overrides the global rule to run `task test:ci` before every commit proposal: in this repo it builds the base
image (about 4-5 GB), so it is reserved for major refactors.

- Default: `task lint` (pre-commit hooks plus actionlint). No image builds.
- Also build and test the base image (`task test:ci`, then `task ci:local` if workflows changed) only after a
  major refactor:
  - restructuring the Dockerfile: moving, merging or splitting layers or stages, or changing the base image;
  - changing the user or shell setup, or the logic of `verify-installation.sh`;
  - non-trivial changes to the `scripts/` that run during the build.
- Version bumps, workflow edits and docs changes don't count; CI covers them. Say which checks were skipped.
- After a local build, remove the images it created (`docker rmi devops-base base-image`) once you've asked.

## When CI runs

- `main.yml` (image builds) runs on pushes and pull requests only when an image input changes: `Dockerfile`,
  `.dockerignore`, `aqua.yaml`, `scripts/**`, `main.yml` or `.github/actions/**`. The weekly schedule and manual
  runs always build. If the build needs a new input file, add it to both `paths:` lists in `main.yml`.
- `lint.yml` runs on every push and pull request.
- `[skip ci]` (or `[ci skip]`, `[no ci]`, `[skip actions]`, `[actions skip]`) in the head commit message skips
  every workflow for that push or pull request, lint included. Use it only for changes the path filter wouldn't
  already skip and that can't change behaviour, such as a comment-only edit in an image input. Never on commits
  that change what the image or a workflow does.
