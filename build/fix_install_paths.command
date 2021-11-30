#!/usr/bin/env bash

cd "$(dirname "$0")"
for dir in iphoneos iphonesimulator; do
	cmakeBaseDir="$dir/lib/cmake"
	boostBaseDir="$cmakeBaseDir/boost_"
	currentInstallPath="$(fgrep 'if(EXISTS "' "$boostBaseDir"date_time-*/boost_date_time-config.cmake | cut -d \" -f 2)"
	newInstallPath="$(pwd)/$cmakeBaseDir"
	echo "fixing Boost install path: $currentInstallPath => $newInstallPath"
	for boostDir in "$boostBaseDir"*; do
		sed -i '' "s|$currentInstallPath|$newInstallPath|g" $boostDir/*.cmake
	done
done
