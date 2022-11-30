#!/bin/bash

set -euxo pipefail

readonly build_from_source="--build-from-source"

function build_xcframework {
    # TODO: Can we support armv7, too? Compilation fails for me locally on a Mac M1...
    readonly archs="arm64"
    readonly opencv_tag="4.6.0"

    [[ -d opencv ]] || git clone git@github.com:opencv/opencv.git

    pushd opencv
    git checkout "${opencv_tag}"
    python platforms/apple/build_xcframework.py \
        -o build \
        --iphoneos_archs "${archs}" \
        --iphonesimulator_archs x86_64,arm64 \
        --build_only_specified_archs
    pushd build

    readonly zipfile="opencv2.xcframework-$(git rev-parse HEAD).zip"
    zip -r "${zipfile}" opencv2.xcframework/

    popd; popd

    mv "opencv/build/${zipfile}" opencv2.xcframework.zip
    ln -s "opencv/build/opencv2.xcframework" opencv2.xcframework
}

function download_xcframework {
    wget "FIXME" -O opencv2.xcframework.zip
    unzip opencv2.xcframework.zip
}


if [[ $# -gt 0 && "$1" == "${build_from_source}" ]]; then
    build_xcframework
fi

if [[ ! -d "./opencv2.xcframework" ]]; then
    download_xcframework
fi
