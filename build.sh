#!/bin/bash

VERSION=$(cat MIDIBlinker.xcodeproj/project.pbxproj | \
          grep -m1 'MARKETING_VERSION' | cut -d'=' -f2 | \
          tr -d ';' | tr -d ' ')
ARCHIVE_DIR=/Users/Larry/Library/Developer/Xcode/Archives/CommandLine

rm -f make.log
touch make.log
rm -rf build

echo "Building MIDIBlinker" 2>&1 | tee -a make.log

xcodebuild -project MIDIBlinker.xcodeproj clean 2>&1 | tee -a make.log
xcodebuild -project MIDIBlinker.xcodeproj \
    -scheme "MIDIBlinker Release" -archivePath MIDIBlinker.xcarchive \
    archive 2>&1 | tee -a make.log

rm -rf ${ARCHIVE_DIR}/MIDIBlinker-v${VERSION}.xcarchive
cp -rf MIDIBlinker.xcarchive ${ARCHIVE_DIR}/MIDIBlinker-v${VERSION}.xcarchive

