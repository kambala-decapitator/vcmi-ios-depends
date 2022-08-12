#!/usr/bin/env bash

tbbVersion='2021.5.0'

echo "Downloading TBB"
tbbName=oneTBB
tbbInstallPrefix="install-tbb"
downloadArchive "https://github.com/oneapi-src/$tbbName/archive/refs/tags/v$tbbVersion.tar.gz"

# TODO: remove when https://github.com/oneapi-src/oneTBB/pull/860 is merged
echo -e "\nPatching TBB"
cd "$tbbName-"*
patch -p1 < "$repoRootDir/patches/tbb-armv7.patch" || exit 1
cd ..

if [[ $hasNinja ]]; then
	generator='Ninja'
else
	cmakeBuildOptions="-- -j$makeThreads"
fi

tbbPlatforms='OS OS64 SIMULATOR64'
if [[ $armSimulatorEnabled ]]; then
	tbbPlatforms+=' SIMULATORARM64'
fi
for platform in $tbbPlatforms ; do
	case $platform in
	OS)
		tbbInstallDir="$tbbInstallPrefix-armv7"
		archs='armv7'
		;;
	OS64)
		tbbInstallDir="$baseInstallDir/$deviceDir"
		archs=
		;;
	SIMULATOR64)
		tbbInstallDir="$baseInstallDir/$simulatorDir"
		archs=
		;;
	SIMULATORARM64)
		tbbInstallDir="$tbbInstallPrefix-arm64-simulator"
		archs=
		;;
	esac
	tbbBuildDir="build-tbb-$platform"
	echo -e "\nbuild TBB for platform $platform"
	cmake -S "$tbbName-"* -B "$tbbBuildDir" \
		${generator:+ -G "$generator"} \
		-DTBB_TEST=OFF \
		-DTBBMALLOC_BUILD=OFF \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX="$tbbInstallDir" \
		--toolchain "$repoRootDir/ios-cmake/ios.toolchain.cmake" \
		-DPLATFORM="$platform" \
		${archs:+ -DARCHS="$archs"} \
		-DDEPLOYMENT_TARGET="$mainDeploymentTarget" \
		-DENABLE_BITCODE=OFF \
		-DENABLE_ARC=ON \
		-DENABLE_VISIBILITY=ON \
	&& cmake --build "$tbbBuildDir" --target install $cmakeBuildOptions \
		|| exit 1
done

echo -e "\nMerge TBB libs"
for arch in armv7 arm64 ; do
	if [[ "$arch" == armv7 ]]; then
		destDir="$deviceDir"
	else
		destDir="$simulatorDir"
	fi
	for lib in $(find "$tbbInstallPrefix-$arch"*/lib -depth 1 -type f); do
		installedLib="$baseInstallDir/$destDir/lib/$(basename "$lib")"
		lipo -create -output "$installedLib" "$installedLib" "$lib"
	done
done
echo
