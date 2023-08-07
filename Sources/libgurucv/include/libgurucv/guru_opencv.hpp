#include <opencv2/opencv.hpp>
#include <memory>

namespace opencv {

    static JSClassID js_mat_class_id = 42;

    typedef struct {
        std::unique_ptr<cv::Mat> m;
    } JSMat;

    int js_init_module(JSContext* ctx);
    JSValue js_new_mat(JSContext* ctx, cv::Mat& image);
}