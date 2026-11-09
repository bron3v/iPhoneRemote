# Contributing

**English** · [Italiano](CONTRIBUTING.it.md)

This project is a local development preview. Before proposing changes, read
[README.md](README.md), [SECURITY.md](SECURITY.md), and
[Docs/TECHNICAL-ANALYSIS.md](Docs/TECHNICAL-ANALYSIS.md) (Italian).

## Development environment

You need a Mac with the full Xcode installation, Git, and Python 3. The Mac target
has no external Swift Package dependencies. Simulated tests do not require an
iPhone or Apple Account. WDA is downloaded separately at a pinned commit by
`Scripts/bootstrap-wda.sh`.

```sh
Scripts/verify.sh
python3 -m unittest discover -s Tests/Publication -v
```

On a Mac with a desktop session, you can also run `Scripts/verify-experience.sh`.
Hardware tests are separate: describe the device model, software versions, and
observed behavior without publishing identifiers or personal content.

## Changes

- Keep the Mac app on public APIs; explicitly disclose WDA's private XCTest dependency.
- Do not add SIP disabling, passcode bypasses, or false success reports.
- Avoid automatically replaying actions with uncertain outcomes and preserve queue limits.
- Text and chat tests must use simulated responses; do not send real messages to third parties.
- Add useful checks for behavior changes and distinguish them from hardware tests.
- If you add Swift files, run `python3 Scripts/generate-project.py` and include the updated project.
- If you update WDA, review the commit, APIs used, provisioning, and licenses of all affected files.
- Do not add compiled runners, provisioning profiles, personal screenshots, or local configuration.

For a pull request, describe the problem, resulting behavior, checks performed,
and limitations. Do not claim a configuration has been tested on hardware when
you have only built it.

## Contribution licensing

Original contributions are submitted under the project's MIT license.
Identify the source and license of any external material; do not copy code
without the necessary rights or attribution. Dependencies retain their own terms.
