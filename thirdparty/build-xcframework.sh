#!/bin/bash

set -euxo pipefail

readonly build_from_source="--build-from-source"
readonly opencv_sha="b0dc474160e389b9c9045da5db49d03ae17c6a6b"  # 4.6.0

function checkout_opencv {
    [[ -d opencv ]] || git clone git@github.com:opencv/opencv.git
    pushd opencv
    git checkout "${opencv_sha}"
    popd
}

function build_xcframework {
    # TODO: Can we support armv7, too? Compilation fails for me locally on a Mac M1...
    readonly archs="arm64"
    checkout_opencv

    pushd opencv
    python platforms/apple/build_xcframework.py \
        -o build \
        --iphoneos_archs "${archs}" \
        --iphonesimulator_archs x86_64,arm64 \
        --build_only_specified_archs
    pushd build

    readonly zipfile="opencv2.xcframework-${opencv_sha}.zip"
    zip -r "${zipfile}" opencv2.xcframework/

    popd; popd

    mv "opencv/build/${zipfile}" .
    ln -s "opencv/build/opencv2.xcframework" opencv2.xcframework
}

function download_xcframework {
    readonly zipfile="opencv2.xcframework-${opencv_sha}.zip"
    wget "https://formguru-datasets.s3.us-west-2.amazonaws.com/opencv2_ios_builds/${zipfile}" -O opencv2.xcframework.zip
    unzip opencv2.xcframework.zip
}


if [[ $# -gt 0 && "$1" == "${build_from_source}" ]]; then
    build_xcframework
elif [[ ! -d "./opencv2.xcframework" ]]; then
    download_xcframework
fi
