#!/usr/bin/env bash

qtVersion='5.15.5'

echo "Downloading Qt"
qtVersionMajorMinor=${qtVersion%.*}
downloadArchive "https://download.qt.io/official_releases/qt/$qtVersionMajorMinor/$qtVersion/submodules/qtbase-everywhere-opensource-src-$qtVersion.tar.xz"

echo "Downloading Qt patches"
qtPatchesRepo='Qt5-iOS-patches'
qtPatchesRepoDir='5.15.5'

git clone --no-checkout --depth 1 --sparse "https://github.com/kambala-decapitator/$qtPatchesRepo.git"
cd "$qtPatchesRepo"
git sparse-checkout add "$qtPatchesRepoDir"
git checkout
cd ..

mkdir qt-build
ln -s qtbase-* qtbase

echo -e "\nApplying Qt patches"
for p in ios10 qmake ; do
  patch -p1 < "$qtPatchesRepo/$qtPatchesRepoDir/$p.patch"
done

cd qtbase
for p in "../$qtPatchesRepo/$qtPatchesRepoDir/kde-patches"/* ; do
  patch -p1 < "$p"
done
cd ../qt-build

qtConfigure="../qtbase/configure \
-opensource \
-confirm-license \
-release \
-strip \
-static \
-xplatform macx-ios-clang \
-make libs \
-no-compile-examples \
-no-dbus \
-system-zlib \
-no-openssl \
-no-freetype \
-no-harfbuzz \
-no-gif \
-no-ico \
-system-sqlite"

for sdk in "$deviceSdk" "$simulatorSdk"; do
	echo -e "\nBuilding Qt for $sdk"
	$qtConfigure -prefix "$baseInstallDir/$sdk" -sdk "$sdk"
	make --silent -j$makeThreads install || exit 1
	# remove everything but qmake as it makes no sense to rebuild it
	find . -depth 1 ! -name bin ! -name qmake -exec rm -rf {} +
	find bin -type f ! -name qmake -exec rm -rf {} +
done

if [[ $armSimulatorEnabled ]]; then
	echo -e "\nBuilding Qt for $simulatorSdk arm64"
	sed -i '' \
		's/QMAKE_APPLE_SIMULATOR_ARCHS = x86_64/QMAKE_APPLE_SIMULATOR_ARCHS = arm64/' \
		../qtbase/mkspecs/macx-ios-clang/qmake.conf
	$qtConfigure -prefix "$baseInstallDir/$simulatorSdk" -sdk "$simulatorSdk"
	make --silent -j$makeThreads || exit 1

	echo 'Merge Qt simulator libs'
	for lib in $(find . -type f -name '*.a' ! -name libQt5Bootstrap.a); do
		installedLib="$baseInstallDir/$simulatorDir/$lib"
		lipo -create -output "$installedLib" "$installedLib" "$lib"
	done
fi
