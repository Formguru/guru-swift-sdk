//
//  preprocess.hpp
//  Runner
//
//  Created by Andrew Stahlman on 6/16/22.
//

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

//struct Keypoint {
//    float x, y, score;
//};
//
//struct InferenceResults {
//    Keypoint keypoints[NUM_COCO_KEYPOINTS];
//};
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

struct PreprocessedImage {
    struct RgbImage image;
    struct CenterScale center_scale;
};

const struct ImageFeat do_preprocess(struct RgbImage, struct Bbox, bool withAlpha);
const struct PreprocessedImage do_preprocess2(struct RgbImage, struct Bbox, bool withAlpha);

struct CenterScale _get_center_scale(struct Bbox bbox);


#ifdef __cplusplus
}
#endif


#endif /* preprocess_hpp */
