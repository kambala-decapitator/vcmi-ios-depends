#!/usr/bin/env bash

ffmpegVersion='ffmpeg-4.4.2'

function ffmpegLibArchPath {
	echo "prebuilt/apple-ios-$1-lts/ffmpeg"
}

function mergeFFmpegLibs {
	dir="$1"
	shift
	ffmpegInstallPath=$(ffmpegLibArchPath $1)
	rsync --archive --exclude-from=- "$ffmpegInstallPath/include/" "$dir/include" <<<'config.h'
	for lib in $(ls "$ffmpegInstallPath/lib"/*.a); do
		libName=$(basename "$lib")
		libPaths=""
		for arch; do
			libPaths+="$(ffmpegLibArchPath "$arch")/lib/$libName "
		done
		lipo -create -output "$dir/lib/$libName" $libPaths
	done
}

echo 'cloning FFmpeg build script'
ffmpegKitName='ffmpeg-kit'
git clone --depth 1 --branch "$ffmpegVersion" "https://github.com/kambala-decapitator/$ffmpegKitName.git"

pushd "$ffmpegKitName" > /dev/null
declare -a deviceArchs=( \
	arm64 \
	armv7 \
)
declare -a simulatorArchs=( \
	x86_64 \
)
if [[ $armSimulatorEnabled ]]; then
	simulatorArchs[1]=arm64-simulator
else
	disableArmSimulatorOption=--disable-arm64-simulator
fi
SKIP_ffmpeg_kit=1 ./ios.sh \
	--speed \
	--lts \
	--target="$mainDeploymentTarget" \
	$disableArmSimulatorOption \
	--disable-armv7s \
	--disable-arm64-mac-catalyst \
	--disable-arm64e \
	--disable-i386 \
	--disable-x86-64-mac-catalyst \
	--enable-ios-audiotoolbox \
	--enable-ios-avfoundation \
	--enable-ios-videotoolbox \
	--enable-ios-bzip2 \
	--enable-ios-zlib \
	--enable-ios-libiconv \
	--no-framework

echo 'merging FFmpeg libraries'
mergeFFmpegLibs "../../$deviceDir" "${deviceArchs[@]}"
mergeFFmpegLibs "../../$simulatorDir" "${simulatorArchs[@]}"
echo
popd > /dev/null
