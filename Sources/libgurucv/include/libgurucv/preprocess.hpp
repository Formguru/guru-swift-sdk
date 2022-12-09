/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

#ifndef preprocess_hpp
#define preprocess_hpp

#include <stdio.h>
#include <math.h>
#include <stdbool.h>

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

#ifdef __cplusplus
}
#endif


#endif /* preprocess_hpp */
