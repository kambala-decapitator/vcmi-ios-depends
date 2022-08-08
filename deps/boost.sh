#!/usr/bin/env bash

boostVersion='1.79.0'

echo "Downloading Boost build script"
boostRepoName='Apple-Boost-BuildScript'
downloadArchive "https://github.com/kambala-decapitator/$boostRepoName/archive/refs/heads/all-improvements-from-PRs.zip"

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
echo
popd > /dev/null
