#!/usr/bin/env bash

ffmpegVersion='ffmpeg-4.4.2'
sdlVersion='2.0.22'
sdlImageVersion='2.0.5'
sdlMixerVersion='64120a41f62310a8be9bb97116e15a95a892e39d' # 2.6.1 results in infinite recursion in VCMI
sdlTtfVersion='2.20.0'
boostVersion='1.79.0'
tbbVersion='2021.5.0'
luaJitVersion='50936d784474747b4569d988767f1b5bab8bb6d0'

mainDeploymentTarget='9.3'
nullkillerDeploymentTarget='11.0'

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

function downloadGithubZip {
	curl -L "$1" | tar -xf -
	echo
}

function downloadSdlLib {
	echo "Downloading library $1 version $2"
	if [[ "$3" == 'commit' ]]; then
		downloadPath="$2.zip"
	else
		downloadPath="refs/tags/release-$2.tar.gz"
	fi
	downloadGithubZip "https://github.com/libsdl-org/$1/archive/$downloadPath"
}


# main script start
if ! xcrun --find xcodebuild ; then
	echo 'xcodebuild not found. Use xcode-select program or set DEVELOPER_DIR environment variable.'
	exit 1
fi

xcodeVersion=$(./xcode_version.sh)
xcodeMajorVersion=${xcodeVersion%%.*}

if [[ $xcodeMajorVersion -ge 12 ]]; then
	armSimulatorEnabled=1
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

# FFmpeg
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

# SDL
sdlName='SDL'
sdlImageName='SDL_image'
sdlMixerName='SDL_mixer'
sdlTtfName='SDL_ttf'

downloadSdlLib "$sdlName" "$sdlVersion"
downloadSdlLib "$sdlImageName" "$sdlImageVersion"
downloadSdlLib "$sdlMixerName" "$sdlMixerVersion" commit

# SDL_ttf source is downloaded from release assets rather than simple tag to have dependencies included
sdlTtfDirName=${sdlTtfName/SDL/SDL2}
downloadGithubZip "https://github.com/libsdl-org/$sdlTtfName/releases/download/release-$sdlTtfVersion/$sdlTtfDirName-$sdlTtfVersion.tar.gz"
ln -s "$sdlTtfDirName"-* "$sdlTtfName-$sdlTtfVersion"

# other SDL libraries need SDL headers that are expected to be in 'SDL' directory
ln -s "$sdlName"-* "$sdlName"

# search for SDL headers in the symlinked dir
sdlXcconfig=$(mktemp)
echo "HEADER_SEARCH_PATHS = $(pwd)/$sdlName/include \$(inherited)" > "$sdlXcconfig"

for sdlLib in "$sdlName" "$sdlImageName" "$sdlMixerName" "$sdlTtfName"; do
	case $sdlLib in
	"$sdlName")
		xcodeProjectDir='Xcode/SDL'
		xcodeTarget='Static Library-iOS'
		;;
	"$sdlTtfName")
		xcodeProjectDir='Xcode'
		xcodeTarget='Static Library'
		;;
	*)
		xcodeProjectDir='Xcode-iOS'
		xcodeTarget="lib$sdlLib-iOS"
		;;
	esac

	sdlLibDir="$sdlLib"-*
	for sdk in "$deviceSdk" "$simulatorSdk"; do
		if [[ "$sdk" == "$simulatorSdk" ]]; then
			excludedArchs='i386'
			if [[ -z "$armSimulatorEnabled" ]]; then
				excludedArchs+=' arm64'
			fi
		else
			excludedArchs=
		fi

		echo "building $sdlLib for $sdk"
		installDir="$baseInstallDir/$sdk"
		xcodebuild \
			-project $sdlLibDir/"$xcodeProjectDir"/*.xcodeproj \
			-target "$xcodeTarget" \
			-configuration 'Release' \
			-sdk "$sdk" \
			-xcconfig "$sdlXcconfig" \
			-quiet \
			ENABLE_BITCODE=NO \
			"EXCLUDED_ARCHS=$excludedArchs" \
			CONFIGURATION_BUILD_DIR="$installDir/lib" \
			IPHONEOS_DEPLOYMENT_TARGET="$mainDeploymentTarget" \
			PLATFORM=iOS \
				|| exit 1
		echo -e "\ncopying $sdlLib headers for $sdk"
		rsync --archive $sdlLibDir/include/ $sdlLibDir/"$sdlLib.h" "$installDir/include/SDL2"
		echo
	done
done
rm -f "$sdlXcconfig"

# Boost
echo "Downloading Boost build script"
boostRepoName='Apple-Boost-BuildScript'
downloadGithubZip "https://github.com/kambala-decapitator/$boostRepoName/archive/refs/heads/all-improvements-from-PRs.zip"

pushd "$boostRepoName"-* > /dev/null
boostScript=./boost.sh
chmod +x $boostScript

echo "Building Boost"
$boostScript \
	-ios \
	--shared \
	--boost-version "$boostVersion" \
	--min-ios-version "$mainDeploymentTarget" \
	--boost-libs 'date_time filesystem locale program_options system thread' \
	--no-framework \
	--no-thinning \
	--prefix "$baseInstallDir"

for buildTarget in iphone iphonesim; do
	if [[ "$buildTarget" == iphone ]]; then
		sdk="$deviceSdk"
	else
		sdk="$simulatorSdk"
	fi
	libInstallDir="$baseInstallDir/$sdk/lib"
	boostStageDir=$(cd src/boost_*/"$buildTarget"-build/stage/lib ; pwd)

	# fix install path
	echo "fixing Boost install path: $boostStageDir => $libInstallDir"
	for boostDir in "$libInstallDir"/cmake/boost_*-"$boostVersion"; do
		sed -i '' \
			-e "s|$boostStageDir|$libInstallDir|g" \
			-e 's|_BOOST_INCLUDEDIR "${_BOOST_CMAKEDIR}/../../../../"|_BOOST_INCLUDEDIR "${_BOOST_CMAKEDIR}/../../include/"|' \
			$boostDir/*.cmake
	done
done
popd > /dev/null

# TBB
echo "Downloading TBB"
tbbName=oneTBB
tbbInstallPrefix="install-tbb"
downloadGithubZip "https://github.com/oneapi-src/$tbbName/archive/refs/tags/v$tbbVersion.tar.gz"

tbbPlatforms='OS64 SIMULATOR64'
if [[ $armSimulatorEnabled ]]; then
	tbbPlatforms+=' SIMULATORARM64'
fi
for platform in $tbbPlatforms ; do
	case $platform in
	OS64)
		tbbInstallDir="$baseInstallDir/$deviceDir"
		;;
	SIMULATOR64)
		tbbInstallDir="$baseInstallDir/$simulatorDir"
		;;
	SIMULATORARM64)
		tbbInstallDir="$tbbInstallPrefix-arm64-simulator"
		;;
	esac
	tbbBuildDir="build-tbb-$platform"
	echo -e "\nbuild TBB for platform $platform"
	cmake -S "$tbbName-"* -B "$tbbBuildDir" \
		-DTBB_TEST=OFF \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_TOOLCHAIN_FILE="$repoRootDir/ios-cmake/ios.toolchain.cmake" \
		-DPLATFORM="$platform" \
		-DDEPLOYMENT_TARGET="$nullkillerDeploymentTarget" \
		-DENABLE_BITCODE=OFF \
		-DENABLE_ARC=ON \
		-DENABLE_VISIBILITY=ON \
	&& cmake --build "$tbbBuildDir" -- -j$makeThreads \
	&& cmake --install "$tbbBuildDir" --prefix "$tbbInstallDir" \
		|| exit 1
done

echo 'Merge TBB simulator libs'
for lib in $(find "$tbbInstallPrefix"*/lib -depth 1 -type f); do
	installedLib="$baseInstallDir/$simulatorDir/lib/$(basename "$lib")"
	lipo -create -output "$installedLib" "$installedLib" "$lib"
done

# LuaJIT
echo "Downloading LuaJIT"
luajitName=LuaJIT
downloadGithubZip "https://github.com/LuaJIT/$luajitName/archive/$luaJitVersion.zip"
cCompiler=clang
toolchainDir=$(dirname "$(xcrun --find "$cCompiler")")
luajitInstallPrefix="install-$luajitName"
for sdk in "$deviceSdk" "$simulatorSdk"; do
	sdkPath=$(xcrun --sdk "$sdk" --show-sdk-path)
	if [[ "$sdk" == "$deviceSdk" ]]; then
		archs='arm64'
		targetSuffix=
	else
		archs='x86_64'
		if [[ $armSimulatorEnabled ]]; then
			archs+=' arm64'
		fi
		targetSuffix='-simulator'
	fi
	for arch in $archs; do
		echo -e "\nbuild $luajitName for $sdk-$arch"
		if [[ "$arch" == arm64 ]]; then
			installDir="$baseInstallDir/$sdk"
		else
			installDir="$(pwd)/$luajitInstallPrefix-$sdk-$arch"
		fi
		makeCommand="make -C $luajitName-* -j$makeThreads TARGET_SYS=iOS"
		$makeCommand \
			BUILDMODE=static \
			DEFAULT_CC="$cCompiler" \
			CROSS="$toolchainDir/" \
			TARGET_FLAGS="-isysroot $sdkPath -target $arch-apple-ios$nullkillerDeploymentTarget$targetSuffix" \
		&& $makeCommand install PREFIX="$installDir" \
		&& $makeCommand clean \
			|| exit 1
	done
done

echo -e "\nMerge $luajitName simulator libs"
for lib in $(find "$luajitInstallPrefix"*/lib -depth 1 -type f); do
	installedLib="$baseInstallDir/$simulatorDir/lib/$(basename "$lib")"
	lipo -create -output "$installedLib" "$installedLib" "$lib"
done

popd > /dev/null

echo -e "\ncleanup"
rm -rf "$buildDir/src" "$buildDir"/{"$deviceDir","$simulatorDir"}/bin
echo 'done'
