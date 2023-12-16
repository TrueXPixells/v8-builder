# V8 Builder
High re-write of https://github.com/tbossi/v8-builder
#### An automatic V8 monolith builder via Github Actions

[![Build V8](https://github.com/TrueXPixells/v8-builder/actions/workflows/build.yml/badge.svg)](https://github.com/TrueXPixells/v8-builder)

## Building info
**V8 is compiled as is**, without patches or changes of any kind.
The version used to compile is the most recent stable shown at https://omahaproxy.appspot.com (as described [here](https://v8.dev/docs/source-code#source-code-branches)).

V8 binaries are built for the following platforms:
- Linux (armv7, arm64, x64)
- Android (armv7, arm64, x64, x86)
- macOS (x64, arm64)
- Windows (x64, arm64)

Headers are included!

## Releases
See [release](https://github.com/truexpixells/v8-builder/releases) for available versions to download.
