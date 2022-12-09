/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */


#include <stdio.h>
#include <libgurucv/preprocess.hpp>
#include <opencv2/opencv.hpp>

#define IS_INTERACTIVE 1


// TODO: figure out how to run this automatically in a way that's compatible with XCode builds
int test_preprocess_steph() {
  cv::Mat mat = cv::imread("./steph.jpg");
  
  struct RgbImage image;
  image.height = mat.rows;
  image.width = mat.cols;
  image.rgb = mat.data;
  
  struct Bbox bbox;
  bbox.x = 60;
  bbox.y = 26;
  bbox.w = 280;
  bbox.h = 571;
  
  // I don't know of a better way to do this than via visual inspection.
  // If this is working, the person should be centered in the frame and
  // ~200px tall
  
  struct RgbImage img = do_preprocess_as_img(image, bbox);
  cv::Mat m = cv::Mat(192, 256, CV_8UC3, img.rgb);
  cv::imwrite("preprocessed-output.jpg", m);
  if (IS_INTERACTIVE) {
    cv::imshow("Pre-processed image", m);
    cv::waitKey(0);
  }
  return 0;
}
