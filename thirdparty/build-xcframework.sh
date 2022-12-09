#!/bin/bash

#######################################################
# This builds and packages OpenCV as a .xcframework. We
# upload this file to S3 and reference it as a remote
# binary target from Package.swift
#######################################################

set -euo pipefail

# The OpenCV git commit to build from
readonly opencv_sha="b0dc474160e389b9c9045da5db49d03ae17c6a6b"  # 4.6.0

function checkout_opencv {
    [[ -d opencv ]] || git clone git@github.com:opencv/opencv.git
    pushd opencv
    git checkout "${opencv_sha}"
    popd
}

function build_xcframework {
    checkout_opencv

    pushd opencv
    python platforms/apple/build_xcframework.py \
        -o build \
        --iphoneos_archs arm64 \
        --iphonesimulator_archs x86_64,arm64 \
        --build_only_specified_archs
    pushd build

    readonly zipfile="opencv2.xcframework-${opencv_sha}.zip"
    zip -r "${zipfile}" opencv2.xcframework/
    popd; popd
    mv "opencv/build/${zipfile}" .
    checksum=$(swift package compute-checksum "${zipfile}")

    echo ""
    echo "===================================================="
    echo "Finished building package. Next steps:"
    echo "  1. Upload ${zipfile} to S3"
    echo "  2. Update Package.swift as follows:"
    echo "===================================================="
    echo "
        .binaryTarget(
          name: "opencv2",
          url: "https://formguru-datasets.s3.us-west-2.amazonaws.com/opencv2_ios_builds/${zipfile}",
          checksum: ${checksum}
        ),
    "
}

build_xcframework
