# VCMI dependencies for iOS

Library dependencies for iOS platform of [VCMI project](https://github.com/vcmi/vcmi).

Current status:

- all dependencies target iOS 10.0 and are available for both 32- and 64-bit
- both 64-bit simulators (Intel and ARM) are supported, the 32-bit one is not (although it should be possible to build for it)

## Using prebuilt package

Download prebuilt libraries from [Releases](https://github.com/kambala-decapitator/vcmi-ios-depends/releases) page (they are created with GitHub Actions), unpack the archive and run `fix_install_paths.command` script (either by double-clicking it or from Terminal). Full build instructions are available on [VCMI wiki](https://wiki.vcmi.eu/How_to_build_VCMI_(iOS)).

If you move the unpacked directory later, you also need to run the script, as it fixes absolute paths in Boost's CMake config files.

### Note for arm Macs

Qt is built on an Intel host, hence host Qt tools (MOC, UIC etc.) are x86_64. To obtain their native versions, you need to configure Qt manually and then build only those tools.

1. Download and unpack [qtbase module](https://download.qt.io/official_releases/qt/5.15/5.15.5/submodules/qtbase-everywhere-opensource-src-5.15.5.tar.xz).
2. From some build directory execute:

```bash
PATH/TO/DOWNLOADED/QTBASE/configure -opensource -confirm-license -release -no-debug-and-release -static -no-framework -nomake examples -no-compile-examples -no-freetype -no-harfbuzz -no-gif -no-ico \
  && make --silent --jobs=$(sysctl -n hw.ncpu) sub-src-qmake_all \
  && make --silent --jobs=$(sysctl -n hw.ncpu) --directory=src sub-bootstrap sub-moc sub-qlalr sub-rcc sub-tracegen sub-uic
```

3. The host tools will appear in `bin` directory inside your build directory. Copy them to either:

- both `build/iphoneos/bin` and `build/iphonesimulator/bin` directories of the prebuilt package
- some directory on your machine and symlink all tools to both `build/iphoneos/bin` and `build/iphonesimulator/bin` directories of the prebuilt package

4. You can safely delete build directory and Qt directory.

## Building from source

[Xcode](https://developer.apple.com/xcode/) is required to build the dependencies. Build has been tested with the following Xcode versions: 13.4.1, 13.2.1, 12.5.1, 12.4, 11.3.1.

Make sure that `xcodebuild` command is available. If it's not, use either of the following ways:

- select an Xcode instance from Xcode application - Preferences - Locations - Command Line Tools
- use `xcode-select` utility to set Xcode path: for example, `sudo xcode-select -s /Applications/Xcode.app`
- set `DEVELOPER_DIR` environment variable pointing to Xcode path: for example, `export DEVELOPER_DIR=/Applications/Xcode.app`

Clone this repository with submodules. Then simply run `./build_depends.sh` and wait, the result will appear in `build` directory.
