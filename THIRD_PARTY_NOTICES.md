# Third-party notices

The MIT license in `LICENSE` covers this project's original source code,
documentation, and original icon assets. It does not relicense dependencies,
Apple SDKs, or operating-system resources.

## Appium WebDriverAgent

- Upstream: https://github.com/appium/WebDriverAgent
- Pinned revision: `3d6a4e03cdd673e540289c610f7e189f8ffea434`
- Package version at that revision: `16.15.3`
- This repository contains the HTTP client, not the WDA implementation.
  `Scripts/bootstrap-wda.sh` downloads upstream separately into ignored `Research/`.
- WDA's root `LICENSE` and most implementation headers specify BSD terms:
  Copyright (c) 2015-present, Facebook, Inc. All rights reserved.
  The unmodified text is in `ThirdPartyLicenses/WebDriverAgent-BSD.txt`.
- The pinned upstream `package.json` declares Apache-2.0. Some implementation
  files explicitly carry Apache-2.0 headers, including
  `WebDriverAgentLib/Routing/FBHTTPStatusCodes.h` and
  `WebDriverAgentLib/Utilities/LRUCache/*`.
  Apache-2.0 text is included in `ThirdPartyLicenses/Apache-2.0.txt`.
- `FBHTTPStatusCodes.h` states: Copyright (C) 2013 Neo Visionaries Inc.
- LRUCache's headers refer to a NOTICE file; none was found in the pinned WDA
  checkout. No missing attribution is invented here. Preserve upstream headers,
  metadata, and any additional notices when updating or redistributing WDA.

The licensing metadata is therefore not summarized as one uniform license.
The local installer includes these notices, both license texts, the upstream root
license, and the runner source with its file-level notices. A public binary
release needs a fresh dependency/license review; the source archive generated
by this project does not contain a prebuilt WDA runner.

WDA uses private XCTest APIs and is a separate development test runner.
Neither Appium nor Meta endorses this application.

## libusbmuxd / iproxy

`iproxy` is a separately installed runtime tool. No libusbmuxd executable or
source is bundled in this repository or source archive. Consult the version
installed through Homebrew and its upstream notices before redistributing it:
https://github.com/libimobiledevice/libusbmuxd

## Apple frameworks and symbols

SwiftUI, AppKit, AVFoundation, CoreMediaIO, Security, and SF Symbols used by the
interface are provided by the operating system/SDK under Apple's terms. They
are not distributed as project-owned assets. No Apple logo is included.

## Original icon

The icon was generated with ImageGen and prepared with Apple's `sips` and
`iconutil`. Prompts and provenance are recorded in `Assets/ICON.md`.

## Research references

DimCyan/iOS-remote was reviewed as an architectural reference. No GPL-licensed
implementation from that project is included in this repository.
