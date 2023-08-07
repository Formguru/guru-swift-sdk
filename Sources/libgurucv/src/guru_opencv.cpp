#include "../include/quickjs/quickjs.h"
#include "../include/libgurucv/guru_opencv.hpp"
#include "../include/libgurucv/cutils.h"

namespace opencv {

    // TODO: add finalizer
    // static void js_mat_finalizer(JSRuntime *rt, JSValue val) {
    //     JSMat* s = (JSMat*) JS_GetOpaque(val, js_mat_class_id);
    //     if (s) {
    //         if (s->m) {
    //             s->m->release();
    //         }
    //         js_free_rt(rt, s);
    //     }
    // }

    static JSClassDef js_mat_class = {
        "Mat",
        // .finalizer = js_mat_finalizer,
    }; 


    int js_init_module(JSContext *ctx) {
        JS_NewClassID(&js_mat_class_id);
        JS_NewClass(JS_GetRuntime(ctx), js_mat_class_id, &js_mat_class);
        JSValue proto = JS_NewObject(ctx);
        // TODO: add functions to the class prototype?
        JS_SetClassProto(ctx, js_mat_class_id, proto);
        return 0;
    }

    JSValue js_new_mat(JSContext* ctx, cv::Mat& original) {
        JSMat* s = (JSMat*) js_mallocz(ctx, sizeof(JSMat));
        printf("sizeof(*s) = %lu\n", sizeof(*s));
        if (!s) {
            throw new std::runtime_error("Failed to instantiate");
        }
        s->m = make_unique<cv::Mat>(original);
        printf("Creating matrix with class_id = %d, size = %dx%d\n", js_mat_class_id, s->m->cols, s->m->rows);
        JSValue obj = JS_NewObjectClass(ctx, js_mat_class_id);
        if (JS_IsException(obj)) {
            throw new std::runtime_error("Failed to instantiate");
        }
        JS_SetOpaque(obj, s);
        return obj;
    }
}
