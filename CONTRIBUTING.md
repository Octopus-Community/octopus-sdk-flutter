# Contributing

Thanks for contributing to the Octopus Flutter SDK. This guide covers local setup, the checks CI runs, and our commit / PR conventions.

## Prerequisites

- Flutter `>=3.10.0` (Dart `>=3.0.0 <4.0.0`) — see [`pubspec.yaml`](pubspec.yaml).
- For the example app on a real backend: a demo API key (see [Example app](#example-app)).

## Setup

```bash
flutter pub get
cd example && flutter pub get && cd ..
```

## Checks (run before pushing)

CI (`.github/workflows/pr.yml`) gates every PR on these. Run them locally first:

```bash
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
flutter pub publish --dry-run   # publishability gate
```

A secret scan (`gitleaks detect --no-git`) also runs in CI — never commit credentials.

## Example app

The example app reads its demo API key from `--dart-define`, injected at build time. **No key is ever committed to this repo** (the public mirror ships none — bring your own). Internally, keys live in the internal-tooling `shared/config/secrets.local.yaml` source of truth; run the example with:

```bash
flutter run --dart-define=OCTOPUS_API_KEY=<your-demo-key>
```

## Commit conventions

[Conventional Commits 1.0.0](https://www.conventionalcommits.org/):

```
type(scope): short imperative description
```

- **Types**: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `style`, `perf`, `ci`, `build`.
- Breaking changes: add `!` after the type/scope (`feat(api)!: ...`) and a `BREAKING CHANGE:` footer.
- The release tooling derives the next version and the CHANGELOG from commit / PR-title history, so keep them accurate.

## Branches

- Feature: `feature/<description>`
- Fix: `fix/<description>`
- Chore / tooling: `chore/<description>` · CI: `ci/<description>`
- Release: `release/vX.Y.Z`

## Pull requests

- **The PR title is the squash-merge commit subject** — write it as a Conventional Commit (e.g. `feat(api): add ApiServer model`). The release tool reads it.
- Fill in [`PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md): a `## Summary` and a `## Test plan`.
- At least one CODEOWNERS review is required.
- **Squash-merge** — we keep a linear history.

These conventions mirror the Octopus org-wide engineering standards shared across the Android, iOS, Flutter, and React Native SDKs.
