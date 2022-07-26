//
// VipnasEndToEnd.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
class VipnasEndToEndInput : MLFeatureProvider {

    /// image_nchw as color (kCVPixelFormatType_32BGRA) image buffer, 480 pixels wide by 640 pixels high
    var image_nchw: CVPixelBuffer

    /// bbox_xywh as 1 by 4 matrix of floats
    var bbox_xywh: MLMultiArray

    var featureNames: Set<String> {
        get {
            return ["image_nchw", "bbox_xywh"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "image_nchw") {
            return MLFeatureValue(pixelBuffer: image_nchw)
        }
        if (featureName == "bbox_xywh") {
            return MLFeatureValue(multiArray: bbox_xywh)
        }
        return nil
    }
    
    init(image_nchw: CVPixelBuffer, bbox_xywh: MLMultiArray) {
        self.image_nchw = image_nchw
        self.bbox_xywh = bbox_xywh
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    convenience init(image_nchw: CVPixelBuffer, bbox_xywh: MLShapedArray<Float>) {
        self.init(image_nchw: image_nchw, bbox_xywh: MLMultiArray(bbox_xywh))
    }

    convenience init(image_nchwWith image_nchw: CGImage, bbox_xywh: MLMultiArray) throws {
        self.init(image_nchw: try MLFeatureValue(cgImage: image_nchw, pixelsWide: 480, pixelsHigh: 640, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!, bbox_xywh: bbox_xywh)
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    convenience init(image_nchwWith image_nchw: CGImage, bbox_xywh: MLShapedArray<Float>) throws {
        self.init(image_nchw: try MLFeatureValue(cgImage: image_nchw, pixelsWide: 480, pixelsHigh: 640, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!, bbox_xywh: MLMultiArray(bbox_xywh))
    }

    convenience init(image_nchwAt image_nchw: URL, bbox_xywh: MLMultiArray) throws {
        self.init(image_nchw: try MLFeatureValue(imageAt: image_nchw, pixelsWide: 480, pixelsHigh: 640, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!, bbox_xywh: bbox_xywh)
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    convenience init(image_nchwAt image_nchw: URL, bbox_xywh: MLShapedArray<Float>) throws {
        self.init(image_nchw: try MLFeatureValue(imageAt: image_nchw, pixelsWide: 480, pixelsHigh: 640, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!, bbox_xywh: MLMultiArray(bbox_xywh))
    }

    func setImage_nchw(with image_nchw: CGImage) throws  {
        self.image_nchw = try MLFeatureValue(cgImage: image_nchw, pixelsWide: 480, pixelsHigh: 640, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }

    func setImage_nchw(with image_nchw: URL) throws  {
        self.image_nchw = try MLFeatureValue(imageAt: image_nchw, pixelsWide: 480, pixelsHigh: 640, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }

}


/// Model Prediction Output Type
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
class VipnasEndToEndOutput : MLFeatureProvider {

    /// Source provided by CoreML
    private let provider : MLFeatureProvider

    /// keypoints as multidimensional array of floats
    lazy var keypoints: MLMultiArray = {
        [unowned self] in return self.provider.featureValue(for: "keypoints")!.multiArrayValue
    }()!

    /// keypoints as multidimensional array of floats
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    var keypointsShapedArray: MLShapedArray<Float> {
        return MLShapedArray<Float>(self.keypoints)
    }

    /// scores as multidimensional array of floats
    lazy var scores: MLMultiArray = {
        [unowned self] in return self.provider.featureValue(for: "scores")!.multiArrayValue
    }()!

    /// scores as multidimensional array of floats
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    var scoresShapedArray: MLShapedArray<Float> {
        return MLShapedArray<Float>(self.scores)
    }

    var featureNames: Set<String> {
        return self.provider.featureNames
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return self.provider.featureValue(for: featureName)
    }

    init(keypoints: MLMultiArray, scores: MLMultiArray) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["keypoints" : MLFeatureValue(multiArray: keypoints), "scores" : MLFeatureValue(multiArray: scores)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
class VipnasEndToEnd {
    let model: MLModel

    /// URL of model assuming it was installed in the same bundle as this class
    class var urlOfModelInThisBundle : URL {
        let bundle = Bundle(for: self)
        return bundle.url(forResource: "VipnasEndToEnd", withExtension:"mlmodelc")!
    }

    /**
        Construct VipnasEndToEnd instance with an existing MLModel object.

        Usually the application does not use this initializer unless it makes a subclass of VipnasEndToEnd.
        Such application may want to use `MLModel(contentsOfURL:configuration:)` and `VipnasEndToEnd.urlOfModelInThisBundle` to create a MLModel object to pass-in.

        - parameters:
          - model: MLModel object
    */
    init(model: MLModel) {
        self.model = model
    }

    /**
        Construct a model with configuration

        - parameters:
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(configuration: MLModelConfiguration = MLModelConfiguration()) throws {
        try self.init(contentsOf: type(of:self).urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct VipnasEndToEnd instance with explicit path to mlmodelc file
        - parameters:
           - modelURL: the file url of the model

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL) throws {
        try self.init(model: MLModel(contentsOf: modelURL))
    }

    /**
        Construct a model with URL of the .mlmodelc directory and configuration

        - parameters:
           - modelURL: the file url of the model
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL, configuration: MLModelConfiguration) throws {
        try self.init(model: MLModel(contentsOf: modelURL, configuration: configuration))
    }

    /**
        Construct VipnasEndToEnd instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    class func load(configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<VipnasEndToEnd, Error>) -> Void) {
        return self.load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration, completionHandler: handler)
    }

    /**
        Construct VipnasEndToEnd instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
    */
    class func load(configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> VipnasEndToEnd {
        return try await self.load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct VipnasEndToEnd instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<VipnasEndToEnd, Error>) -> Void) {
        MLModel.load(contentsOf: modelURL, configuration: configuration) { result in
            switch result {
            case .failure(let error):
                handler(.failure(error))
            case .success(let model):
                handler(.success(VipnasEndToEnd(model: model)))
            }
        }
    }

    /**
        Construct VipnasEndToEnd instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
    */
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> VipnasEndToEnd {
        let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
        return VipnasEndToEnd(model: model)
    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as VipnasEndToEndInput

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as VipnasEndToEndOutput
    */
    func prediction(input: VipnasEndToEndInput) throws -> VipnasEndToEndOutput {
        return try self.prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as VipnasEndToEndInput
           - options: prediction options 

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as VipnasEndToEndOutput
    */
    func prediction(input: VipnasEndToEndInput, options: MLPredictionOptions) throws -> VipnasEndToEndOutput {
        let outFeatures = try model.prediction(from: input, options:options)
        return VipnasEndToEndOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface

        - parameters:
            - image_nchw as color (kCVPixelFormatType_32BGRA) image buffer, 480 pixels wide by 640 pixels high
            - bbox_xywh as 1 by 4 matrix of floats

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as VipnasEndToEndOutput
    */
    func prediction(image_nchw: CVPixelBuffer, bbox_xywh: MLMultiArray) throws -> VipnasEndToEndOutput {
        let input_ = VipnasEndToEndInput(image_nchw: image_nchw, bbox_xywh: bbox_xywh)
        return try self.prediction(input: input_)
    }

    /**
        Make a prediction using the convenience interface

        - parameters:
            - image_nchw as color (kCVPixelFormatType_32BGRA) image buffer, 480 pixels wide by 640 pixels high
            - bbox_xywh as 1 by 4 matrix of floats

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as VipnasEndToEndOutput
    */

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    func prediction(image_nchw: CVPixelBuffer, bbox_xywh: MLShapedArray<Float>) throws -> VipnasEndToEndOutput {
        let input_ = VipnasEndToEndInput(image_nchw: image_nchw, bbox_xywh: bbox_xywh)
        return try self.prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface

        - parameters:
           - inputs: the inputs to the prediction as [VipnasEndToEndInput]
           - options: prediction options 

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as [VipnasEndToEndOutput]
    */
    func predictions(inputs: [VipnasEndToEndInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [VipnasEndToEndOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [VipnasEndToEndOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  VipnasEndToEndOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
