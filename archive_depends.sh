#!/usr/bin/env bash
tar --create --xz --file "$1/vcmi-ios-depends-xc$(./xcode_version.sh).txz" build
