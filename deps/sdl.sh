#!/usr/bin/env bash

sdlVersion='2.0.22'
sdlImageVersion='2.0.5'
sdlMixerVersion='64120a41f62310a8be9bb97116e15a95a892e39d' # 2.6.1 results in infinite recursion in VCMI
sdlTtfVersion='2.20.0'

function downloadSdlLib {
	echo "Downloading library $1 version $2"
	if [[ "$3" == 'commit' ]]; then
		downloadPath="$2.zip"
	else
		downloadPath="refs/tags/release-$2.tar.gz"
	fi
	downloadArchive "https://github.com/libsdl-org/$1/archive/$downloadPath"
}

sdlName='SDL'
sdlImageName='SDL_image'
sdlMixerName='SDL_mixer'
sdlTtfName='SDL_ttf'

downloadSdlLib "$sdlName" "$sdlVersion"
downloadSdlLib "$sdlImageName" "$sdlImageVersion"
downloadSdlLib "$sdlMixerName" "$sdlMixerVersion" commit

# SDL_ttf source is downloaded from release assets rather than simple tag to have dependencies included
sdlTtfDirName=${sdlTtfName/SDL/SDL2}
downloadArchive "https://github.com/libsdl-org/$sdlTtfName/releases/download/release-$sdlTtfVersion/$sdlTtfDirName-$sdlTtfVersion.tar.gz"
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
