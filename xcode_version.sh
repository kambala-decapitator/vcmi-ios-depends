#!/usr/bin/env bash
xcodebuild -version | head -1 | awk '{print $2}'
