#include <libgurucv/preprocess.hpp>
#include <opencv2/opencv.hpp>
#include <iostream>


int zzzmain() {
  std::cout << "starting...\n";
  // cv::Mat mat = cv::imread("/Users/astahlman/code/app/ios/GuruTests/pushup.jpg");
  cv::Mat bgr = cv::imread("/Users/astahlman/code/app/ios/GuruTests/steph.jpg", cv::IMREAD_COLOR);
  std::cout << "done reading...\n";
  cv::imshow("Original (BGR)", bgr);
  cv::waitKey(0);
  cv::Mat rgb = bgr;
  cv::cvtColor(bgr, rgb, cv::COLOR_BGR2RGBA);
  cv::imshow("Original (RGBA)", rgb);
  cv::waitKey(0);
  
  
  struct RgbImage image;
  image.height = rgb.rows;
  image.width = rgb.cols;
  image.rgb = rgb.clone().data;
  
  struct Bbox bbox;
  // bbox.x = 170;
  // bbox.y = 57;
  // bbox.w = 883;
  // bbox.h = 661;
  bbox.x = 0;
  bbox.y = 0;
  bbox.w = 480;
  bbox.h = 640;
  bool withAlpha = true;
  struct PreprocessedImage img = do_preprocess2(image, bbox, withAlpha);
  // cv::Mat mat2 = cv::Mat(img.image.height, img.image.width, CV_8UC4, img.image.rgb);
  cv::Mat mat2 = cv::Mat(img.image.height, img.image.width, CV_8UC3, img.image.rgb);
  std::cout << "height, width = " << img.image.height << ", " << img.image.width << std::endl;
  std::cout << mat2 << std::endl;
  cv::imshow("Preprocessed - 0", mat2);
  int k = cv::waitKey(0);
  struct ImageFeat feat = do_preprocess(image, bbox, withAlpha);
  return 0;
}
