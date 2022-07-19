#!/usr/bin/env bash

sdlVersion='2.0.22'
sdlImageVersion='2.6.0'
sdlMixerVersion='64120a41f62310a8be9bb97116e15a95a892e39d' # 2.6.1 results in infinite recursion in VCMI
sdlTtfVersion='2.20.0'
boostVersion='1.79.0'
tbbVersion='2021.5.0'
luaJitVersion='50936d784474747b4569d988767f1b5bab8bb6d0'

mainDeploymentTarget='9.3'
nullkillerDeploymentTarget='11.0'

sdlPrefix=SDL2


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
	sdlLib="${sdlPrefix}$1"
	echo "Downloading library $sdlLib version $2"
	downloadGithubZip "https://github.com/libsdl-org/SDL$1/releases/download/release-$2/$sdlLib-$2.tar.gz"
}


# main script start
if ! xcrun --find xcodebuild ; then
	echo 'xcodebuild not found. Use xcode-select program or set DEVELOPER_DIR environment variable.'
	exit 1
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
git clone --depth 1 --branch 'ffmpeg-release' "https://github.com/kambala-decapitator/$ffmpegKitName.git"

pushd "$ffmpegKitName" > /dev/null
declare -a deviceArchs=( \
	arm64 \
	armv7 \
)
declare -a simulatorArchs=( \
	arm64-simulator \
	x86_64 \
)
SKIP_ffmpeg_kit=1 ./ios.sh \
	--speed \
	--lts \
	--target="$mainDeploymentTarget" \
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
sdlSuffix=''
sdlImageSuffix='_image'
sdlMixerSuffix='_mixer'
sdlTtfSuffix='_ttf'

downloadSdlLib "$sdlSuffix" "$sdlVersion"
downloadSdlLib "$sdlImageSuffix" "$sdlImageVersion"
downloadSdlLib "$sdlTtfSuffix" "$sdlTtfVersion"

# mixer is locked to commit instead of release
sdlMixerLib="SDL$sdlMixerSuffix"
downloadGithubZip "https://github.com/libsdl-org/$sdlMixerLib/archive/$sdlMixerVersion.zip"
# SDL headers are expected to be in a sibling 'SDL' directory
ln -s "$sdlPrefix"-* SDL

# fix linking section of SDL_image: linking to ApplicationServices.framework must be done only on macOS
# this essentially appends `platformFilters = (macos, );` to `/* ApplicationServices.framework */;` that has no filters
sed -i '' \
	-e 's|/\* ApplicationServices\.framework \*/; };|/* ApplicationServices.framework */; platformFilters = (macos, ); };|' \
	"${sdlPrefix}$sdlImageSuffix"-*/Xcode/*.xcodeproj/project.pbxproj

for suffix in "$sdlSuffix" "$sdlImageSuffix" "$sdlMixerSuffix" "$sdlTtfSuffix"; do
	case $suffix in
	"$sdlSuffix")
		xcodeProjectDir='Xcode/SDL'
		xcodeTarget='Static Library-iOS'
		;;
	"$sdlMixerSuffix")
		xcodeProjectDir='Xcode-iOS'
		xcodeTarget="lib$sdlMixerLib-iOS"
		;;
	*)
		xcodeProjectDir='Xcode'
		xcodeTarget='Static Library'
		;;
	esac

	if [[ "$suffix" == "$sdlMixerSuffix" ]]; then
		sdlLib="$sdlMixerLib"
	else
		sdlLib="${sdlPrefix}$suffix"
	fi

	sdlLibDir="$sdlLib"-*
	for sdk in "$deviceSdk" "$simulatorSdk"; do
		echo "building $sdlLib for $sdk"
		installDir="$baseInstallDir/$sdk"
		xcodebuild \
			-project $sdlLibDir/"$xcodeProjectDir"/*.xcodeproj \
			-target "$xcodeTarget" \
			-configuration 'Release' \
			-sdk "$sdk" \
			-quiet \
			ENABLE_BITCODE=NO \
			EXCLUDED_ARCHS=i386 \
			CONFIGURATION_BUILD_DIR="$installDir/lib" \
			IPHONEOS_DEPLOYMENT_TARGET="$mainDeploymentTarget" \
			PLATFORM=iOS \
				|| exit 1
		echo -e "\ncopying $sdlLib headers for $sdk"
		rsync --archive $sdlLibDir/include/ $sdlLibDir/"SDL$suffix.h" "$installDir/include/SDL2"
		echo
	done
done

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

	echo "copying Boost libs for $sdk"
	rsync --archive "$boostStageDir/" "$libInstallDir"
	echo

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
for platform in OS64 SIMULATOR64 SIMULATORARM64; do
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
		archs='x86_64 arm64'
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
