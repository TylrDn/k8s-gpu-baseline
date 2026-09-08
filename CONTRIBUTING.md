# Contributing

Thanks for helping improve `k8s-gpu-baseline`. This repository is deliberately
small and readable; changes that keep it that way are the most welcome kind.

## Before you start

Everything here must be verifiable against a real cluster or a real upstream
document. Two rules that are enforced in review:

1. **No invented facts.** No adoption claims, benchmark numbers, endorsements,
   or "used in production at ..." statements. If a manifest does not create an
   object, do not document the object.
2. **Document the gaps.** If a component is incomplete relative to its upstream
   distribution, add it to the "Known gaps" table in the README instead of
   glossing over it.

## Local setup

```bash
# pinned to the versions CI uses
curl -LO "https://dl.k8s.io/release/v1.30.2/bin/linux/amd64/kubectl"   # kubectl v1.30.2
pip install pre-commit
pre-commit install
```

Also useful: `kubeconform` v0.6.4, `shellcheck`, `kind`, `jq`.

## Checks to run before opening a PR

```bash
make render                                    # both overlays must build
kubectl kustomize kustomize/overlays/prod | kubeconform -strict -
kubectl kustomize kustomize/overlays/dev  | kubeconform -strict -
pre-commit run --all-files
shellcheck scripts/smoke.sh
```

`make lint` runs the last two. CI (`.github/workflows/ci.yaml`) runs all of
them; keep it green.

If you have access to a GPU cluster, also run `./scripts/smoke.sh` and paste the
output into the PR. On a CPU-only cluster the GPU checks skip rather than fail,
which is still a useful signal.

## Changing manifests

- Pin every image to an explicit tag and state the tag in the README component
  table.
- Keep dev-only relaxations (anything insecure but convenient) out of `base` and
  `overlays/prod`; they belong in `overlays/dev`.
- Use `patches:` in overlays. `patchesStrategicMerge` is deprecated in
  Kustomize v5.
- After any manifest change, re-check the rendered object count and the
  prod/dev diff quoted in the README, and update them if they moved.

## Changing scripts/smoke.sh

- Must stay shellcheck-clean and keep `set -euo pipefail`.
- Missing GPUs are a `SKIP`, not a `PASS` and not a `FAIL`. Never make a check
  look like it succeeded when it did not run.
- Keep the exit-code contract: `0` all executed checks passed, `1` a check
  failed, `2` the cluster is unreachable. Update the table in
  `docs/gpu-baseline.md` if it changes.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):
`feat:`, `fix:`, `docs:`, `refactor:`, `style:`, `test:`, `ci:`, `chore:`,
with an optional scope such as `fix(kustomize):`. One logical change per commit;
explain *why* in the body, and quote the error output you are fixing where
there is one.

## Versioning and releases

[Semantic Versioning](https://semver.org/spec/v2.0.0.html), interpreted for a
manifest repository:

- **MAJOR** — a change that requires action from an existing user: an object is
  renamed, moved between namespaces, or deleted; an overlay path changes; the
  smoke-test exit-code contract changes.
- **MINOR** — a new component, manifest, overlay, doc or Make target;
  backwards-compatible image bumps.
- **PATCH** — bug fixes to existing manifests, docs corrections, CI and lint
  changes.

Release checklist:

1. `make render`, `kubeconform -strict` on both overlays, and
   `pre-commit run --all-files` all pass on `main`.
2. Move the `## [Unreleased]` entries in `CHANGELOG.md` into a new
   `## [X.Y.Z] - YYYY-MM-DD` section and update the link definitions at the
   bottom of the file.
3. Confirm the README component table still matches the manifests (images,
   namespaces, object names) and that the quoted prod/dev diff is current.
4. Commit as `chore(release): vX.Y.Z`.
5. `git tag -a vX.Y.Z -m "vX.Y.Z" && git push --follow-tags`.
6. Create the GitHub release from the changelog section.

## Code of conduct

Participation is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
