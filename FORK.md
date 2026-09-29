# CamerTrace fork of `whimo-ios`

This repository is **CamerTrace** (traçabilité du cacao et du café au Cameroun),
a fork of [EuropeanForestInstitute/whimo-ios](https://github.com/EuropeanForestInstitute/whimo-ios)
(MIT licence; keep `LICENCE`/`LICENSE` and EFI's copyright notice).

Two goals drive how it is organised:

1. **Keep pulling EFI's work** with as few conflicts as possible.
2. **Contribute back to EFI** with pull requests that contain *no* CamerTrace
   branding, text or configuration.

## Branches

| Branch | Content | Rule |
|---|---|---|
| `main` | exact copy of `upstream/main` | only `git merge --ff-only upstream/main`, never commit here |
| `camertrace` | `main` + brand overlay + Cameroon features | default branch, the one deployed; receives `main` by **merge** |
| `feat/*`, `fix/*` | generic work, candidate for EFI | branch from **`main`**, PR to EFI, then merge into `camertrace` |
| `cm/*` | Cameroon-only work | branch from **`camertrace`**, PR to `prosygma/whimo-ios:camertrace` |
| `archive/*` | history before this model (2026-09-29) | read-only |

## First time on a new clone

```bash
scripts/fork-setup.sh     # upstream remote, push to EFI disabled, rerere, merge=ours driver
```

## Pulling EFI's changes

```bash
git fetch upstream
git switch main && git merge --ff-only upstream/main && git push origin main
git switch camertrace && git merge main          # resolve, build, test
git push origin camertrace
```

`rerere` replays conflict resolutions you already made once. Binary brand files
listed in `.gitattributes` with `merge=ours` always keep the CamerTrace version.
Text brand files (theme, config) are **not** auto-resolved on purpose: when EFI
adds a new token or key, you want to see it and give it a CamerTrace value.

## Sending a change to EFI

```bash
git switch -c feat/my-change main     # from main, NOT from camertrace
# ... work, commit (English, generic wording, EFI's defaults) ...
scripts/check-upstream-clean.sh feat/my-change
git push origin feat/my-change        # open the PR on GitHub: base = EFI main
git switch camertrace && git merge feat/my-change
```

Rules for an upstream-bound change:

- never mention CamerTrace, CICC, prosygma, `camertrace.cm`;
- new user-visible text: add the key to EFI's locale files (en, and fr/es when
  you can) with neutral wording; CamerTrace wording goes in the brand overlay;
- new colour, logo or name: add it to the brand layer with EFI's value as the
  default, then give it the CamerTrace value on `camertrace` only.

`check-upstream-clean.sh` fails on the words in `.fork/forbidden-words` and
warns about paths in `.fork/brand-paths`.

## Where the CamerTrace brand lives

iOS has no brand layer yet: the CamerTrace values replace EFI's **in place**,
in a short, stable list of spots (expect small, easy conflicts there on merges):

| Where | CamerTrace value |
|---|---|
| `Whimo.xcodeproj/project.pbxproj`, `APP_DISPLAY_NAME` (3 configurations) | CamerTrace, CamerTrace DEV, CamerTrace STAGE |
| `Packages/Resources/.../Localization/*/Localizable.strings` | `general.appName` and the 4 invite/account strings |
| `Whimo/Resources/Assets.xcassets/splashScreen.imageset/splashScreen.pdf` | seal + CamerTrace + slogan (360×800 pt, text outlined) |
| `Whimo/Resources/Assets.xcassets/AppIcon*.appiconset/*.jpg` | emblem icon (dev / stage with a band) |
| `Whimo/Services/EmailClient/...DefaultEmailRecipients.swift` | feedback e-mail subject |

**Not done yet (needs Xcode):**

- **Colours.** `primary-sea-blue` and `primary-midnight-blue` are also the
  *conditional* and *incomplete* traceability colours (in
  `TransactionModel+Extension.swift` and the ChartView files), so recolouring them
  would break the status scale. The clean fix is an upstream-able white-label PR:
  semantic colour sets (`brand-primary`, `brand-surface-dark`…) used by the UI,
  and dedicated `traceability-*` colour sets, with SwiftGen regenerated.
- **Brand configuration.** Moving `APP_DISPLAY_NAME`, bundle ID and app-icon name
  into a `Config/Brand.xcconfig` selected per configuration.
- **Bundle identifier.** Still `com.maddevs.Whimo…`; changing it needs a new App
  Store Connect app and provisioning profiles.

Brand sources (logos, graphic chart, export scripts) are outside the repo, in
`Documents/whimo/logos/camertrace-cicc/` (`charte-graphique.html`,
`render.sh`, `declinaisons/`).
