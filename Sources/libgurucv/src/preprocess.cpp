//
//  preprocess.cpp
//  Runner
//
//  Created by Andrew Stahlman on 6/16/22.
//

#include <libgurucv/preprocess.hpp>
#include <opencv2/opencv.hpp>

#include <iostream>


const int WIDTH = 192;
const int HEIGHT = 256;
const float ASPECT_RATIO = ((float) WIDTH) / HEIGHT;
const float PIXEL_STD = 200.0;
const float PADDING = 1.25;


struct Point {
  float x, y;
  
  Point(float x, float y): x(x), y(y) {}
  
  Point operator+(const Point& p) const {
    return Point(x + p.x, y + p.y);
  }
  Point operator-(const Point& p) const {
    return Point(x - p.x, y - p.y);
  }
  Point operator*(float k) const {
    return Point(x * k, y * k);
  }
  std::ostream & operator<<(std::ostream& str) {
    str << "(" << x << ", " << y << ")";
    return str;
  }
};

cv::Mat _preprocess(struct RgbImage image, struct Bbox bbox, bool with_alpha);
cv::Mat _affine_transform(cv::Mat, CenterScale);
cv::Mat _normalize(cv::Mat);
cv::Mat _hwc_to_chw(cv::Mat src);
int _get_max(cv::Mat);
struct CenterScale _get_null_center_scale(struct Bbox bbox);
struct ImageFeat _to_feat(cv::Mat mat, struct CenterScale center_scale, int height, int width);
struct RgbImage _to_image(cv::Mat mat, int height, int width);
template<typename T> void print_matrix(std::string, cv::Mat);


const struct ImageFeat do_preprocess(
                                            struct RgbImage image,
                                            struct Bbox bbox,
                                            bool with_alpha
                                     ) {

  struct ImageFeat feat;
  feat.center_scale = _get_center_scale(bbox);
  
  cv::Mat m = _preprocess(image, bbox, with_alpha);
  m = _normalize(m);
  m = _hwc_to_chw(m);
  auto sz_bytes = 3 * HEIGHT * WIDTH * sizeof(float32_t);
  feat.rawValues = (float32_t*) malloc(sz_bytes);
  memcpy(feat.rawValues, m.data, sz_bytes);
  return feat;
}

cv::Mat _preprocess(
                                              struct RgbImage image,
                                              struct Bbox bbox,
                                              bool with_alpha
                    ) {
  cv::Mat img;
  if (with_alpha) {
    img = cv::Mat(image.height, image.width, CV_8UC4, image.rgb);
    cv::cvtColor(img, img, cv::COLOR_RGBA2RGB);
  } else {
    img = cv::Mat(image.height, image.width, CV_8UC3, image.rgb);
  }
  
  struct CenterScale center_scale = _get_center_scale(bbox);
  cv::Mat resized = _affine_transform(img, center_scale);
  assert(resized.isContinuous());
  return resized;
}

const struct PreprocessedImage do_preprocess2(
                                              struct RgbImage image,
                                              struct Bbox bbox,
                                              bool with_alpha
                                              ) {

  struct PreprocessedImage result;
  result.center_scale = _get_center_scale(bbox);
  cv::Mat m = _preprocess(image, bbox, with_alpha);
  result.image = _to_image(m, HEIGHT, WIDTH);
  return result;
}


struct ImageFeat _to_feat(cv::Mat mat, struct CenterScale center_scale, int height, int width) {
  struct ImageFeat result;
  result.center_scale = center_scale;
  int num_channels = 3;
  // int num_bytes = mat.cols * mat.rows * sizeof(float32_t) * num_channels;
  int num_bytes = sizeof(float32_t) * height * width * num_channels;
  result.rawValues = (float32_t*) malloc(num_bytes);
  memcpy(result.rawValues, mat.data, num_bytes);
  return result;
}

struct RgbImage _to_image(cv::Mat mat, int height, int width) {
  struct RgbImage image;
  image.height = height;
  image.width = width;
  int num_channels = 3;
  int num_bytes = height * width * sizeof(uint8_t) * num_channels;
  image.rgb = (uchar*) malloc(num_bytes);
  memcpy(image.rgb, mat.data, num_bytes);
  return image;
}

struct CenterScale _get_null_center_scale(struct Bbox bbox) {
  float h = HEIGHT;
  float w = WIDTH;
  
  CenterScale result = {
    .center_x = static_cast<float>(w / 2.0),
    .center_y = static_cast<float>(h / 2.0),
    // .scale_x = 1.0,
    // .scale_y = 1.0,
    .scale_x = (w / PIXEL_STD) * PADDING,
    .scale_y = (h / PIXEL_STD) * PADDING,
  };
  return result;
}

int _get_max(cv::Mat mat) {
  uint8_t max_val = -1;
  for (int row = 0; row < mat.rows; row++) {
    for (int col = 0; col < mat.cols; col++) {
      for (int channel = 0; channel < 3; channel++) {
        uint8_t val = mat.at<cv::Vec3b>(row, col)[channel];
        if (val > max_val) {
          max_val = val;
        }
      }
    }
  }
  return max_val;
}

struct CenterScale _get_center_scale(struct Bbox bbox) {
  float h = std::max(bbox.w / ASPECT_RATIO, static_cast<float>(bbox.h));
  float w = std::max(bbox.h * ASPECT_RATIO, static_cast<float>(bbox.w));
  
  CenterScale result = {
    .center_x = static_cast<float>(bbox.x + bbox.w / 2.0),
    .center_y = static_cast<float>(bbox.y + bbox.h / 2.0),
    .scale_x = (w / PIXEL_STD) * PADDING,
    .scale_y = (h / PIXEL_STD) * PADDING,
  };
  return result;
}

template<typename T> void print_matrix(std::string name, cv::Mat m) {
  if (!DEBUG) {
    return;
  }
  
  std::cout << name << ".size=" << m.size() << ", .type=" << m.type() << "\n";
  cv::imshow(name, m);
  cv::waitKey(0);
  std::cout << "[\n";
  auto firstNonZero = -1;
  for (auto i = 0; i < m.rows; i++) {
    if ((m.at<T>(0, i) > 1e-4) && firstNonZero == -1) {
      firstNonZero = i;
    }
    if (i <= 2 || i >= m.rows - 2) {
      std::cout << "  ";
      for (auto j = 0; j < m.cols; j++) {
        if (j <= 2 || j >= m.cols - 2) {
          std::cout << "  " << m.at<T>(i, j);
        } else if (j == 3) {
          std::cout << "  . . .";
        }
      }
      std::cout << "\n";
    } else if (i == firstNonZero) {
      auto max_val = -1;
      std::cout << "  ";
      for (auto j = 0; j < m.cols; j++) {
        if (j <= 2 || j >= m.cols - 2) {
          std::cout << "  " << m.at<T>(i, j);
        } else if (j == 3) {
          std::cout << "  . . .";
        }
        if (m.at<T>(i, j) > max_val) {
          max_val = m.at<T>(i, j);
        }
      }
      std::cout << "max=" << max_val << "\n. . . \n";
    } else if (i == 3) {
      std::cout << "  . . .\n";
    }
    if (i == m.rows - 1) {
      std::cout << "]\n";
    }
  }
  std::cout << name << "[0][0] = " << m.at<float>(0, 0) << ", first non-zero row: " << firstNonZero << "\n";
}

Point _get_third_Point(const Point a, const Point b) {
  Point direction = a - b;
  return b + Point(-direction.y, direction.x);
}

cv::Mat _mat_from_Points(Point a, Point b, Point c) {
  cv::Mat m = cv::Mat(3, 2, CV_32F);
  m.at<float32_t>(0, 0) = a.x;
  m.at<float32_t>(0, 1) = a.y;
  m.at<float32_t>(1, 0) = b.x;
  m.at<float32_t>(1, 1) = b.y;
  m.at<float32_t>(2, 0) = c.x;
  m.at<float32_t>(2, 1) = c.y;
  return m;
}

cv::Mat _affine_transform(cv::Mat img, CenterScale center_scale) {
  auto src_w = center_scale.scale_x * PIXEL_STD;
  auto dst_w = WIDTH;
  Point src_dir = Point(0, src_w * -.5);
  Point dst_dir = Point(0, dst_w * -.5);
  
  Point src1 = Point(center_scale.center_x, center_scale.center_y);
  Point src2 = src1 + src_dir;
  Point src3 = _get_third_Point(src1, src2);
  cv::Mat src = _mat_from_Points(src1, src2, src3);
  
  Point dst1 = Point(img.cols, img.rows) * 0.5;
  Point dst2 = dst1 + dst_dir;
  Point dst3 = _get_third_Point(dst1, dst2);
  cv::Mat dst = _mat_from_Points(dst1, dst2, dst3);
  
  cv::Mat output = cv::Mat::zeros(img.size(), img.type());
  cv::Mat T = cv::getAffineTransform(src, dst);
  
  cv::warpAffine(img, output, T, img.size(), 0 | cv::INTER_LINEAR);
  
  auto y1 = output.rows / 2 - 256/2;
  auto y2 = output.rows / 2 + 256/2;
  auto x1 = output.cols / 2 - 192/2;
  auto x2 = output.cols / 2 + 192/2;
  
  cv::Rect roi(x1, y1, x2 - x1, y2 - y1);
  return output(roi).clone();
}


cv::Mat _hwc_to_chw(cv::Mat src) {
  std::vector<cv::Mat> channels;
  cv::split(src, channels);
  
  // Stretch one-channel images to vector
  for (auto &img : channels) {
    img = img.reshape(1, 1);
  }
  
  // Concatenate three vectors to one
  cv::Mat result;
  cv::hconcat(channels, result);
  print_matrix<float_t>("result", result);
  return result.clone();
}

cv::Mat _normalize(cv::Mat src) {
  src.convertTo(src, CV_32F, 1.0/255);
  print_matrix<float_t>("src (after /255)", src);
  float std[] = {0.229, 0.224, 0.225};
  float mean[] = {0.485, 0.456, 0.406};
  src.forEach<cv::Vec3f>
  (
   [mean, std](cv::Vec3f &pixel, const int* position) -> void
   {
     pixel[0] = (pixel[0] - mean[0]) / std[0];
     pixel[1] = (pixel[1] - mean[1]) / std[1];
     pixel[2] = (pixel[2] - mean[2]) / std[2];
   }
   );
  return src;
}



// int main() {
//     cv::Mat mat = cv::imread("/Users/astahlman/code/app/ios/GuruTests/pushup.jpg");
//     print_matrix<uint8_t>("original", mat);
//     struct RgbImage image;
//     image.height = mat.rows;
//     image.width = mat.cols;
//     
//     image.rgb = mat.clone().data;
//     struct Bbox bbox;
//     bbox.x = 170;
//     bbox.y = 57;
//     bbox.w = 883;
//     bbox.h = 661;
//     struct ImageFeat feats = do_preprocess(image, bbox);
//     return 0;
// }
