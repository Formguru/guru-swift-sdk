#include <opencv2/core.hpp>
#include "../quickjs/quickjs.h"

namespace onnx
{

    class Point {
    public:
        float x, y;

        Point(float _x, float _y) :
            x(_x), y(_y) { }
    };

    class KeyPoint {
    public:
        Point p;
        float prob;

        KeyPoint(Point _p, float _prob) :
            p(_p), prob(_prob) { }
    };

    // Initialize the ONNX Javascript module
    JSModuleDef *js_init_module(JSContext *ctx);
    int infer_pose(cv::Mat&, cv::Rect&, std::vector<KeyPoint>&);
}
