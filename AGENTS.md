# Agent notes

## Low disk space

The development machine's root volume is small and often over 90% full. A full image build fills it, and Docker
then fails with `no space left on device` part way through.

- Don't run anything that builds or pulls the full images locally:
  - `task build:gcp`, `task build:aws`, `task build:all`
  - `task test:gcp`, `task test:aws`, `task test:all` (they need those images)
  - `task ci:image` (act build job)
  - `docker build` / `docker pull` of large images
- The base-stage checks (`task test:ci`, `task ci:local`) are smaller, but check `df -h /` first and only run them
  with at least 10 GB free. Otherwise skip them and say so.
- Let the pull request's CI do the full multi-platform builds instead.
- Never delete Docker images, volumes or build cache to make room without asking first.
