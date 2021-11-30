# VCMI dependencies for iOS

Library dependencies for [iOS fork](https://github.com/kambala-decapitator/vcmi).

Current status:

- dependencies of the main application (Boost, FFmpeg and SDL) target iOS 9.3, both 32- and 64-bit
- dependencies of the Nullkiller AI (LuaJIT and TBB) target iOS 11.0, 64-bit only
- both 64-bit simulators (Intel and ARM) are supported, the 32-bit one is not (although it's possible to build for it)

## Using prebuilt package

Download prebuilt libraries from [Releases](https://github.com/kambala-decapitator/vcmi-ios-depends/releases) page, unpack the archive and run `fix_install_paths.command` script (either by double-clicking it or from Terminal).

If you move the unpacked directory later, you also need to run the script.

## Building from source

[Xcode](https://developer.apple.com/xcode/) is required to build the dependencies. The prebuilt package is created using Xcode 12.5.1 / iOS 14.5 SDK, but other versions should work as well.

Make sure that `xcodebuild` command is avaiable. If it's not, use either of the following ways:

- select an Xcode instance from Xcode application - Preferences - Locations - Command Line Tools
- use `xcode-select` utility to set Xcode path: for example, `sudo xcode-select -s /Applications/Xcode.app`
- set `DEVELOPER_DIR` environment variable pointing to Xcode path: for example, `export DEVELOPER_DIR=/Applications/Xcode.app`

Clone this repository with submodules. Then simply run `./build_depends.sh` and wait, the result will appear in `build` directory. On my Mac mini 2018 with 6-core Intel i5 3 GHz the process takes about 20 minutes.
