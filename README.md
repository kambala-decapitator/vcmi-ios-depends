# VCMI dependencies for iOS

Library dependencies for [iOS fork](https://github.com/kambala-decapitator/vcmi).

Current status:

- all dependencies target iOS 10.0
- dependencies of the main application (Boost, FFmpeg, Qt and SDL) are available for both 32- and 64-bit
- dependencies of the Nullkiller AI (LuaJIT and TBB) are 64-bit only, see https://github.com/kambala-decapitator/vcmi/issues/35 for background
- both 64-bit simulators (Intel and ARM) are supported, the 32-bit one is not (although it should be possible to build for it)

## Using prebuilt package

Download prebuilt libraries from [Releases](https://github.com/kambala-decapitator/vcmi-ios-depends/releases) page, unpack the archive and run `fix_install_paths.command` script (either by double-clicking it or from Terminal).

When configuring VCMI for iOS, pass `CMAKE_PREFIX_PATH` pointing to the directory of device or simulator. For example, when configuring for device you'd pass:

    -D CMAKE_PREFIX_PATH=~/Downloads/vcmi-ios-depends/build/iphoneos

If you move the unpacked directory later, you also need to run the script, as it fixes absolute paths in Boost's CMake config files.

The prebuilt packages are created with GitHub Actions.

## Building from source

[Xcode](https://developer.apple.com/xcode/) is required to build the dependencies. Build has been tested with the following Xcode versions: 13.4.1, 13.2.1, 12.5.1, 12.4, 11.3.1.

Make sure that `xcodebuild` command is available. If it's not, use either of the following ways:

- select an Xcode instance from Xcode application - Preferences - Locations - Command Line Tools
- use `xcode-select` utility to set Xcode path: for example, `sudo xcode-select -s /Applications/Xcode.app`
- set `DEVELOPER_DIR` environment variable pointing to Xcode path: for example, `export DEVELOPER_DIR=/Applications/Xcode.app`

Clone this repository with submodules. Then simply run `./build_depends.sh` and wait, the result will appear in `build` directory.
