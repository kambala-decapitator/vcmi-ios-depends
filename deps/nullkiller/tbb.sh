#!/usr/bin/env bash

tbbVersion='2021.5.0'

echo "Downloading TBB"
tbbName=oneTBB
tbbInstallPrefix="install-tbb"
downloadArchive "https://github.com/oneapi-src/$tbbName/archive/refs/tags/v$tbbVersion.tar.gz"

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
		-DTBBMALLOC_BUILD=OFF \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_TOOLCHAIN_FILE="$repoRootDir/ios-cmake/ios.toolchain.cmake" \
		-DPLATFORM="$platform" \
		-DDEPLOYMENT_TARGET="$mainDeploymentTarget" \
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
echo
