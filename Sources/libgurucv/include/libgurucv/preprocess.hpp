/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

#ifndef preprocess_hpp
#define preprocess_hpp

#include <stdio.h>
#include <math.h>
#include <stdbool.h>
#include <opencv2/core.hpp>

#define DEBUG 0

#ifdef __cplusplus
extern "C" {
#endif

    
const int PERSON_CATEGORY = 0;
const int NUM_COCO_KEYPOINTS = 17;

struct Bbox {
    int x, y, w, h;
    uint8_t category;
};

struct CenterScale {
    float center_x, center_y, scale_x, scale_y;
};

struct ImageFeat {
    float* rawValues;
    struct CenterScale center_scale;
};

struct RgbImage {
    unsigned char* rgb;  // flat array, HxWx3
    int height, width;
};

const struct ImageFeat do_preprocess(struct RgbImage, struct Bbox, bool withAlpha);

// exposed for visualization + unit testing
const struct RgbImage do_preprocess_as_img(struct RgbImage, struct Bbox);

struct CenterScale _get_center_scale(struct Bbox bbox);

int test_preprocess_steph();

class PreprocessedImage {
public:
    cv::Mat bitmap;
    cv::Mat feats;
    float scale;
    float xPad;
    float yPad;
    int xOffset;
    int yOffset;
    int originalWidth;
    int originalHeight;

    PreprocessedImage(cv::Mat bitmap_, cv::Mat feats_, float scale_, float xPad_, float yPad_, int xOffset_, int yOffset_, int originalWidth_, int originalHeight_)
            : bitmap(bitmap_), feats(feats_), scale(scale_), xPad(xPad_), yPad(yPad_), xOffset(xOffset_), yOffset(yOffset_), originalWidth(originalWidth_), originalHeight(originalHeight_) {}
};

PreprocessedImage preprocess(cv::Mat image, int dest_width, int dest_height, cv::Rect bounding_box);

#ifdef __cplusplus
}
#endif


#endif /* preprocess_hpp */
