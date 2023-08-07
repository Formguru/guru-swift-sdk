#include <iostream>
#include <exception>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/dnn/dnn.hpp>

#include "../include/onnx/onnxruntime_cxx_api.h"
#include "../include/quickjs/quickjs.h"
#include "../include/libgurucv/cutils.h"
#include "../include/libgurucv/onnx.hpp"
#include "../include/libgurucv/preprocess.hpp"
#include "../include/libgurucv/guru_opencv.hpp"


namespace onnx {

    int infer_pose(Ort::Session& session, cv::Mat& img, cv::Rect& bbox, std::vector<KeyPoint>& keypoints);
    std::vector<KeyPoint> _run_inference(cv::Mat& img);
    void post_process(const Ort::Value& heatmaps, const PreprocessedImage& preprocessed, std::vector<KeyPoint>& keypoints);
    static JSValue js_onnx_run_inference(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv);

    /**
     * These functions will be exported from the ES6 module named "onnx"
     * 
     * Example usage in user_code.mjs:
     * 
     *   import { runInference } from "onnx";
     */
    static const JSCFunctionListEntry js_onnx_funcs[] = {
        JS_CFUNC_DEF("runInference", 1, js_onnx_run_inference),
    };

    static JSValue js_onnx_run_inference(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
        if (argc != 1) {
            return JS_ThrowTypeError(ctx, "Expected 1 argument for run_inference");
        }
        JSValue image = argv[0];
        opencv::JSMat* frame = (opencv::JSMat*) JS_GetOpaque2(ctx, image, opencv::js_mat_class_id);
        printf("[C++] Got the image. Size = %dx%d\n", frame->m->cols, frame->m->rows);
        std::vector<KeyPoint> keypoints = _run_inference(*frame->m);

        /* Return a JS object that looks like this:
            {
                keypoints: [
                    {x: _, y: _, score: _},
                    ...
                ]
            }
        */
        JSValue result = JS_NewObject(ctx);
        JSValue arr = JS_NewArray(ctx);
        for (int k = 0; k < keypoints.size(); k++) {
            JSValue keypoint = JS_NewObject(ctx);
            JS_SetPropertyStr(ctx, keypoint, "x", JS_NewFloat64(ctx, keypoints[k].p.x));
            JS_SetPropertyStr(ctx, keypoint, "y", JS_NewFloat64(ctx, keypoints[k].p.y));
            JS_SetPropertyStr(ctx, keypoint, "score", JS_NewFloat64(ctx, keypoints[k].prob));
            JS_DefinePropertyValueUint32(ctx, arr, k, keypoint, JS_PROP_HAS_VALUE);
        }
        JS_SetPropertyStr(ctx, result, "keypoints", arr);
        return result;
    }

    static int _js_onnx_init(JSContext* ctx, JSModuleDef* m) {
        // TODO: why do we need both SetModuleExportList _and_ AddModuleExportList?
        JS_SetModuleExportList(ctx, m, js_onnx_funcs, countof(js_onnx_funcs));
        return 0;
    }

    /**
     * Initializes the JavaScript module which can be imported in user_code.mjs
     */
    JSModuleDef* js_init_module(JSContext* ctx) {
        JSModuleDef* m = JS_NewCModule(ctx, "onnx", _js_onnx_init);
        if (!m) {
            throw std::runtime_error("Failed to create JS module");
        }
        JS_AddModuleExportList(ctx, m, js_onnx_funcs, countof(js_onnx_funcs));
        return m;
    }


    void _print_type_info(const Ort::TypeInfo& info) {
        auto type_and_shape_info = info.GetTensorTypeAndShapeInfo();
        printf("Type: %d; Shape: [ ", type_and_shape_info.GetElementType());
        for (auto i: type_and_shape_info.GetShape()) {
          std::cout << i << " ";
        }
        std::cout << "]" << std::endl;
    }

    Ort::Session _load_model(std::string model_path) {
        Ort::Env ortEnv = Ort::Env(ORT_LOGGING_LEVEL_ERROR, "GuruEngineOnnx");
        Ort::SessionOptions sess_opt = Ort::SessionOptions();
        Ort::AllocatorWithDefaultOptions allocator;
        Ort::Session ort_session = Ort::Session(nullptr);
        ort_session = Ort::Session(ortEnv, model_path.c_str(), sess_opt);
        size_t num_input_nodes = ort_session.GetInputCount();
        for (int i = 0; i < num_input_nodes; i++) {
            _print_type_info(ort_session.GetInputTypeInfo(i));
        }
        return ort_session;
    }

    std::vector<KeyPoint> _run_inference(cv::Mat& img) {
        printf("Loading the model...\n");
        Ort::Session session = _load_model("vipnas.onnx");  // TODO: expose the load method to JS and just call it once
        printf("Done Loading the model. Running inference...\n");
        cv::Rect bbox = cv::Rect(0, 0, 1, 1);
        printf("Created bbox\n");
        std::vector<KeyPoint> keypoints;
        infer_pose(session, img, bbox, keypoints);
        return keypoints;
    }

    // Copied from guru-android-sdk

    const int INPUT_WIDTH = 192;
    const int INPUT_HEIGHT = 256;
    const int HEATMAP_WIDTH = 48;
    const int HEATMAP_HEIGHT = 64;

    Ort::Env env_(OrtLoggingLevel::ORT_LOGGING_LEVEL_WARNING);
    std::unique_ptr<Ort::Session> session_;
    const std::vector<const char*> input_names { "input" };
    const std::vector<const char*> output_names { "output" };
    const Ort::MemoryInfo memory_info = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
    const std::vector<int64_t> tensor_dims = {1, 3, INPUT_HEIGHT, INPUT_WIDTH};

    Ort::AllocatorWithDefaultOptions allocator;

    void init_model(const char* model_bytes, size_t model_data_len, int num_processors) {
        Ort::SessionOptions session_options;
        session_options.SetIntraOpNumThreads(num_processors);
        // session_options.AddConfigEntry("session.intra_op.allow_spinning", "0");
        session_ = make_unique<Ort::Session>(env_, model_bytes, model_data_len, session_options);
    }

    std::tuple<float, float, float> argmax(const Ort::Value&, int);
    // void post_process(const Ort::Value&, const PreprocessedImage&, std::vector<KeyPoint>&);

    // Useful for visualizing intermediate outputs, i.e., write to /sdcard and then `adb pull`
    void save_mat_to_file(const cv::Mat& mat, const std::string& file_path) {
        std::vector<int> params = {cv::IMWRITE_JPEG_QUALITY, 90};
        assert(cv::imwrite(file_path, mat, params));
    }

    int infer_pose(Ort::Session& session, cv::Mat& img, cv::Rect& bbox, std::vector<KeyPoint>& keypoints) {
        printf("Preprocessing...\n");
        const PreprocessedImage &image = preprocess(img, INPUT_WIDTH, INPUT_HEIGHT, bbox);
        printf("Preprocessed\n");
        cv::Mat nchw = cv::dnn::blobFromImage(image.feats);
        printf("Got blob\n");


        const size_t input_tensor_size = image.feats.total() * image.feats.channels();
        std::vector<Ort::Value> input_tensors;
        input_tensors.push_back(Ort::Value::CreateTensor<float>(
            memory_info,
            (float *)nchw.ptr<float>(0),
            input_tensor_size,
            tensor_dims.data(),
            tensor_dims.size()));
        auto output_tensors = session.Run(
            Ort::RunOptions{nullptr},
            input_names.data(),
            input_tensors.data(),
            1,
            output_names.data(),
            1);

        const Ort::Value& heatmaps = output_tensors.at(0);
        post_process(heatmaps, image, keypoints);
        for (int k = 0; k < keypoints.size(); k++) {
            auto kpt = keypoints[k];
            printf("[Keypoint %d], x = %f, y = %f, score = %f\n", k, kpt.p.x, kpt.p.y, kpt.prob);
        }
        return 0;
    }

    std::tuple<float, float, float> argmax(const Ort::Value& heatmaps, int k) {
        const float* vals = heatmaps.GetTensorData<float>();
        float max_score = std::numeric_limits<float>::lowest();
        int best_row, best_col = 0;
        int k_start = k * HEATMAP_HEIGHT * HEATMAP_WIDTH;
        for (int64_t row = 0; row < HEATMAP_HEIGHT; row++) {
            for (int64_t col = 0; col < HEATMAP_WIDTH; col++) {
                float score = vals[k_start + (row * HEATMAP_WIDTH) + col];
                if (score > max_score) {
                    max_score = score;
                    best_row = row;
                    best_col = col;
                }
            }
        }

        return std::tuple<float, float, float> { best_col, best_row, max_score };
    }

    void post_process(const Ort::Value& heatmaps, const PreprocessedImage& preprocessed, std::vector<KeyPoint>& keypoints) {
        auto shape = heatmaps.GetTensorTypeAndShapeInfo().GetShape();
        auto K = shape.at(1);

        std::vector<int64_t> expected_shape = {1, K, HEATMAP_HEIGHT, HEATMAP_WIDTH };
        assert(expected_shape == shape);

        for (int k = 0; k < K; k++) {
            auto xy_score = argmax(heatmaps, k);
            float x = std::get<0>(xy_score);
            float y = std::get<1>(xy_score);
            float score = std::get<2>(xy_score);

            x *= (INPUT_WIDTH / (float)HEATMAP_WIDTH);
            x -= preprocessed.xPad;
            x /= preprocessed.scale;
            x += preprocessed.xOffset;
            x /= preprocessed.originalWidth;

            y *= (INPUT_HEIGHT / (float)HEATMAP_HEIGHT);
            y -= preprocessed.yPad;
            y /= preprocessed.scale;
            y += preprocessed.yOffset;
            y /= preprocessed.originalHeight;

            keypoints.push_back(KeyPoint(Point(x, y), score));
        }
    }

}
