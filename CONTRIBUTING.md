# Contributing to CamerTrace (iOS app)

CamerTrace is the cocoa and coffee traceability platform of the CICC (Conseil Interprofessionnel
du Cacao et du Café, Cameroon). It is a fork of [WHIMO](https://github.com/EuropeanForestInstitute/whimo-ios)
by the European Forest Institute (EFI), under the MIT licence.

Thank you for helping. This page explains where to send a change and what we check before
merging. [`FORK.md`](FORK.md) explains the branch model in more detail.

## Branches

| Branch | What it holds |
|---|---|
| `main` | An exact copy of EFI's `main`. Nobody commits here. |
| `camertrace` | `main` plus the CamerTrace brand and the Cameroon features. This is the default branch and what is deployed. |
| `feat/*`, `fix/*` | Generic work that every WHIMO deployment could use. Starts from `main`. |
| `cm/*` | Cameroon-only work. Starts from `camertrace`. |
| `archive/*` | Old history, read-only. |

## Where to send your change

1. **Is it useful to every WHIMO deployment?** (a bug fix, a generic feature)
   Branch from `main` as `feat/<topic>` or `fix/<topic>`.
   - Prefer opening the pull request **at EFI**: `EuropeanForestInstitute/whimo-ios`, base `main`.
     CamerTrace gets it at the next EFI sync.
   - If CamerTrace needs it sooner, open a second pull request from the same branch against
     `camertrace` here, and mention the EFI one.
2. **Is it only for CamerTrace or Cameroon?** (CICC rules, wording, brand, local integrations)
   Branch from `camertrace` as `cm/<topic>` and open the pull request against `camertrace` here.

Work on your own fork and open pull requests from it. Keep each pull request to one topic.

### First time on a clone

```bash
git remote add upstream https://github.com/EuropeanForestInstitute/whimo-ios.git
scripts/fork-setup.sh   # disables push to EFI, enables rerere and the merge=ours driver
```

## Rules for every change

- **Brand values live in the brand layer only.** iOS has no brand layer yet: brand values are replaced in place (`APP_DISPLAY_NAME`, `Localizable.strings`, splash and icon assets, colour sets under `Primary/…-brand`); keep them in those places only.
  Components use semantic names (`primary`, `surface-dark`, …), never CamerTrace colours or names.
- **Status colours are not brand colours.** Traceability and transaction status colours stay
  EFI's values.
- **Text.** New text for a generic feature goes into EFI's locale files, with neutral wording.
  CamerTrace wording goes into the brand layer. Give at least English and French.
- **No secrets and no real personal data**, in code, tests, fixtures, screenshots, or issues.
  A CICC card identifies a farmer: use made-up values shaped like real ones. See [`SECURITY.md`](SECURITY.md).
- **Generic branches must stay clean.** Before opening a `feat/*` or `fix/*` pull request, run:

  ```bash
  git fetch upstream
  scripts/check-upstream-clean.sh <your-branch>
  ```

  It fails if the branch adds a CamerTrace-specific word, and warns if it touches brand files.
  CI runs it too.
- **Commits.** Write a short imperative summary (about 72 characters at most), and say *why* in
  the body. Don't mix formatting changes with real changes.

## Develop and test

Requirements: Xcode 16.3 or later on macOS.

```bash
cd scripts && bash project_bootstrap.sh && cd ..   # SwiftLint and other tools
mkdir -p FirebaseSupportingFiles
for env in Dev Stage Prod; do
  cp FirebaseSupportingFiles.example/GoogleService-Info.plist FirebaseSupportingFiles/GoogleService-Info-$env.plist
done
open Whimo.xcodeproj                                # scheme "Whimo Dev"
```

Replace the placeholder plists with real Firebase files for push notifications and Crashlytics.
Never commit them (`FirebaseSupportingFiles/` is gitignored).

**Known gaps** (help welcome):
- The CamerTrace iOS app builds in CI (since 2026-11-24) but has not been run on a device or released yet.
- The captcha URL is still EFI's `https://example.com/captcha` placeholder, which blocks sending
  verification codes. It needs a real page or a "no captcha" fallback, as Android has.
- Phone sign-up has no CamerTrace country default, so every country is refused.
- The bundle ID is still EFI's `com.maddevs.Whimo…`.

CI runs the same checks on every pull request. A pull request needs a passing CI and an approval
from a maintainer (`CODEOWNERS`) before it is merged.

## Licence

By contributing, you agree that your contribution is released under the [MIT licence](LICENSE)
of this repository.
