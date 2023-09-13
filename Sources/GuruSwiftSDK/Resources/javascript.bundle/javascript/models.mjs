class OnnxModel {

    constructor(inputName, session, metadata) {
      this.inputName = inputName;
      this.session = session;
      this.metadata = metadata;
    }
  
    static async load(ort, onnxModelPath, executionProviders={ executionProviders: ['cpu'] }) {
      // const session = await ort.InferenceSession.create(
      //   onnxModelPath,
      //   executionProviders,
      // );
      // TODO: implement InferenceSession.create()
      const session = new ort.InferenceSession(onnxModelPath)
      const inputName = session.inputNames[0];
  
      // TODO: onnxruntime-web doesn't expose the metadata currently.
      //  Find way to not hardcode them.
      const metadata = new OnnxModelMetadata(
        new ImgNormCfg([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
        new ImgSize(192, 256)
      );
  
      return new OnnxModel(inputName, session, metadata);
    }
  }
  
  class ImgNormCfg {
    constructor(mean, std) {
      this.mean = mean;
      this.std = std;
    }
  }
  
  class ImgSize {
    constructor(width, height) {
      this.width = width;
      this.height = height;
    }
  }
  
  class OnnxModelMetadata {
    constructor(normCfg, size) {
      this.normCfg = normCfg;
      this.size = size;
    }
  }
  

class GuruModels {

  constructor(ort, poseModel, personDetectionModel, objectDetectionModel) {
    this._ort = ort;
    this._poseModel = poseModel;
    this._personDetectionModel = personDetectionModel;
    this._objectDetectionModel = objectDetectionModel;
    // this._tokenizer = new PreTrainedTokenizer(clipTokenizerDictionary, clipTokenizerConfig, ort);
  }

  objectDetectionModel() {
    return this._objectDetectionModel;
  }

  ort() {
    return this._ort;
  }

  poseModel() {
    return this._poseModel;
  }

  personDetectionModel() {
    return this._personDetectionModel;
  }

//   tokenizer() {
//     return this._tokenizer;
//   }
}

const loadDefaultGuruModels = () => {
  const MODEL_INFO = {
    pose: "https://formguru-datasets.s3.us-west-2.amazonaws.com/on-device/20230620/vipnas.onnx",
    person_detection: "https://formguru-datasets.s3.us-west-2.amazonaws.com/on-device/20230511/tiny-yolov3.onnx",
    object_detection: "https://formguru-datasets.s3.us-west-2.amazonaws.com/on-device/20230718/owl-vit.onnx",
  };

  const poseModel = OnnxModel.load(ort, 'guru-rtmpose-img-256x192.onnx');
  // const personDetectionModel = OnnxModel.load(ort, 'guru-yolov5s.onnx');
  const objectDetectionModel = 
}

export {OnnxModel, ImgNormCfg, ImgSize, OnnxModelMetadata, GuruModels};