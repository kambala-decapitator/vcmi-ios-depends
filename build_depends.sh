#!/usr/bin/env bash

mainDeploymentTarget='10.0'

function downloadArchive {
	curl -L "$1" | tar -xf -
	echo
}

if ! xcrun --find xcodebuild ; then
	echo 'xcodebuild not found. Use xcode-select program or set DEVELOPER_DIR environment variable.'
	exit 1
fi

xcodeVersion=$(./xcode_version.sh)
xcodeMajorVersion=${xcodeVersion%%.*}

if [[ $xcodeMajorVersion -ge 12 ]]; then
	armSimulatorEnabled=1
fi

if [[ "$(which ninja)" ]]; then
	hasNinja=1
fi

buildDir='build'
deviceSdk='iphoneos'
simulatorSdk='iphonesimulator'
deviceDir="$deviceSdk"
simulatorDir="$simulatorSdk"
makeThreads=$(sysctl -n hw.ncpu)
repoRootDir="$(pwd)"

mkdir -p "$buildDir"/{"$deviceDir","$simulatorDir"}/{include,lib}
mkdir -p "$buildDir/src"

pushd "$buildDir/src" > /dev/null
currentDir="$(pwd)"
baseInstallDir=$(cd "$currentDir/.." ; pwd)

. "$repoRootDir/deps/ffmpeg.sh"
. "$repoRootDir/deps/sdl.sh"
. "$repoRootDir/deps/boost.sh"
. "$repoRootDir/deps/qt.sh"

. "$repoRootDir/deps/nullkiller/tbb.sh"
. "$repoRootDir/deps/nullkiller/luajit.sh"

popd > /dev/null

echo -e "\ncleanup"
rm -rf "$buildDir/src"
echo 'done'
