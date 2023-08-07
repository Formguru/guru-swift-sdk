#include <iostream>
#include <exception>
#include <unistd.h>
#include <chrono>
#include <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <UIKit/UIKit.h>

#include "quickjs.h"
#include "quickjs-libc.h"
#include "onnx.hpp"
#include "guru_opencv.hpp"
#include <memory>

cv::Mat read_image(const char* path) {
    cv::Mat image = cv::imread(path);
    if (!image.data) {
        throw std::runtime_error("No image data");
    }
    return image;
}


JSRuntime *rt = JS_NewRuntime();
JSContext *ctx = JS_NewContext(rt);

#define CLEANUP(v) { JS_FreeContext(ctx); JS_FreeRuntime(rt); return v; }
#define FREE(v) JS_FreeValue(ctx, v);
#define VALIDATE(v) { if(JS_IsException(v)) { print_stack_trace(); CLEANUP(1); } }
#define VALINIT(xx,vv) \
  JSValue xx = vv;\
	VALIDATE(xx)
#define VALPROP(xx,vv,pp) VALINIT(xx, JS_GetPropertyStr(ctx, vv, pp))

static char *read_file(const char *filename, size_t *sz) {
	FILE *f = fopen(filename, "rb");
	if(!f) return NULL;
	long fsize; { fseek(f, 0, SEEK_END); fsize = ftell(f); fseek(f, 0, SEEK_SET); }
	char *buf = (char *)malloc(fsize * sizeof(char));
	*sz = fread((void *) buf, 1, fsize, f);
	fclose(f);
	return buf;
}

void print_stack_trace() {
    JSValue exception = JS_GetException(ctx);
    const char *cstring = JS_ToCString(ctx, exception);
    const char *stack_cstring = NULL;
    if (!JS_IsNull(exception) && !JS_IsUndefined(exception)) {
        JSValue stack = JS_GetPropertyStr(ctx, exception, "stack");
        if (!JS_IsException(stack)) {
            stack_cstring = JS_ToCString(ctx, stack);
            JS_FreeValue(ctx, stack);
        }
    }
    std::cout << "Exception: " << cstring << std::endl;
    std::cout << "Exception stack: " << stack_cstring << std::endl;
}

JSValue process_frame(UIImage* frame) {
  cv::Mat mat = cv::Mat();
  UIImageToMat(frame, mat);
  return process_frame(ctx, mat);
}

JSValue process_frame(JSContext *ctx, cv::Mat& image) {
    JSValue global = JS_GetGlobalObject(ctx);
    JSValue process_frame_js_fn = JS_GetPropertyStr(ctx, global, "processFrame");
    JSValue frame = opencv::js_new_mat(ctx, image);
    JSValue args[] = { frame };
    JSValue ret = JS_Call(ctx, process_frame_js_fn, global, 1, args);
    if (JS_IsException(ret)) {
        JSValue exception = JS_GetException(ctx);
        const char *cstring = JS_ToCString(ctx, exception);
        const char *stack_cstring = NULL;
        if (!JS_IsNull(exception) && !JS_IsUndefined(exception)) {
            JSValue stack = JS_GetPropertyStr(ctx, exception, "stack");
            if (!JS_IsException(stack)) {
                stack_cstring = JS_ToCString(ctx, stack);
                JS_FreeValue(ctx, stack);
            }
        }
        std::cout << "[Exception in user code]: " << stack_cstring << std::endl;
    }
    size_t retlen; const char *retstr = JS_ToCStringLen(ctx, &retlen, ret);
    std::cout << "[Return from user code] " << retstr << std::endl;
    FREE(process_frame_js_fn);
    return ret;
}

static int eval_buf(JSContext *ctx, const char *buf, int buf_len,
                    const char *filename, int eval_flags)
{
    JSValue val;
    int ret;

    if ((eval_flags & JS_EVAL_TYPE_MASK) == JS_EVAL_TYPE_MODULE) {
        /* for the modules, we compile then run to be able to set
           import.meta */
        val = JS_Eval(ctx, buf, buf_len, filename,
                      eval_flags | JS_EVAL_FLAG_COMPILE_ONLY);
        if (!JS_IsException(val)) {
            js_module_set_import_meta(ctx, val, true, true);
            val = JS_EvalFunction(ctx, val);
        }
    } else {
        val = JS_Eval(ctx, buf, buf_len, filename, eval_flags);
    }
    if (JS_IsException(val)) {
        js_std_dump_error(ctx);
        ret = -1;
    } else {
        ret = 0;
    }
    JS_FreeValue(ctx, val);
    return ret;
}

int init_js_context() {
    /*
    Note: Most of this is cribbed from QuickJS's repl (see qjs.c)
    */
	VALINIT(global, JS_GetGlobalObject(ctx))
    js_std_add_helpers(ctx, -1, NULL);
    JS_SetModuleLoaderFunc(rt, NULL, js_module_loader, NULL);
    JS_SetHostPromiseRejectionTracker(rt, js_std_promise_rejection_tracker, NULL);
    onnx::js_init_module(ctx);
    opencv::js_init_module(ctx);

    js_init_module_std(ctx, "std");

    size_t len;
    char* buf;

    /*
    Load the user-supplied Javascript definition of processFrame(). Note this is just a string
    */
    buf = read_file("user_code.mjs", &len);
    // TODO: handle errors if their JS throws an error on eval
    eval_buf(ctx, buf, len, "user_code.mjs", JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY);
    free(buf);
    std::cout << "Loaded user-code" << std::endl;

    // TODO: Do we still need this?
    buf = read_file("shim.mjs", &len);
    eval_buf(ctx, buf, len, "shim.mjs", JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY);
    free(buf);
    std::cout << "Loaded shim" << std::endl;
    return 0;
}

int main(int argc, char *argv[]) {
    if (init_js_context() != 0) {
        std::cout << "Failed to initialize JS context" << std::endl;
        return 1;
    };

    auto target_fps = 1;
    std::chrono::milliseconds interval_ms = std::chrono::milliseconds(1000 / target_fps);
    cv::Mat image = read_image("./messi.png");  // get the next image from the camera
    while (true) {
        js_std_loop(ctx);  // run the JS interpreter's event loop
        std::chrono::milliseconds start_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()
        );
        // image = read_image();  // get the next image from the camera
        std::cout << image.size() << std::endl;
        JSValue promise = process_frame(ctx, image);  // call the user-defined processFrame() JS function

        std::chrono::milliseconds end_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()
        );
        std::chrono::milliseconds elapsed_ms = end_ms - start_ms;
        if (elapsed_ms < interval_ms) {
            std::chrono::milliseconds sleep_ms = interval_ms - elapsed_ms;
            usleep(sleep_ms.count() * 1000);
        }
        // TODO: Call analyze() and renderFrame()
    }
    return 0;
}
