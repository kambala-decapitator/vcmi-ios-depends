#!/usr/bin/env bash

luaJitVersion='50936d784474747b4569d988767f1b5bab8bb6d0'

echo "Downloading LuaJIT"
luajitName=LuaJIT
downloadArchive "https://github.com/LuaJIT/$luajitName/archive/$luaJitVersion.zip"
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
		if [[ "$sdk" == "$deviceSdk" || "$arch" == x86_64 ]]; then
			installDir="$baseInstallDir/$sdk"
		else
			installDir="$(pwd)/$luajitInstallPrefix-$sdk-$arch"
		fi
		makeCommand="make -C $luajitName-* -j$makeThreads TARGET_SYS=iOS"
		$makeCommand \
			BUILDMODE=static \
			DEFAULT_CC="$cCompiler" \
			CROSS="$toolchainDir/" \
			TARGET_FLAGS="-isysroot '$sdkPath' -target $arch-apple-ios$mainDeploymentTarget$targetSuffix" \
		&& $makeCommand install PREFIX="$installDir" \
		&& $makeCommand clean \
			|| exit 1
	done
done

if [[ $armSimulatorEnabled ]]; then
	echo -e "\nMerge $luajitName simulator libs"
	for lib in $(find "$luajitInstallPrefix"*/lib -depth 1 -type f); do
		installedLib="$baseInstallDir/$simulatorDir/lib/$(basename "$lib")"
		lipo -create -output "$installedLib" "$installedLib" "$lib"
	done
fi

echo -e "\nMerge $luajitName prebuilt armv7 lib"
luajitLibName='libluajit-5.1.a'
curl -LO "https://github.com/kambala-decapitator/vcmi-ios-depends/releases/download/LuaJIT-armv7/$luajitLibName"
installedLib="$baseInstallDir/$deviceDir/lib/$luajitLibName"
lipo -create -output "$installedLib" "$installedLib" "$luajitLibName"
