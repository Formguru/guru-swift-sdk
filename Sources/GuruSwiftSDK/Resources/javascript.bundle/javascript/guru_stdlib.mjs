import {
  GURU_KEYPOINTS,
  preprocessedImageToTensor,
  preprocessImageForObjectDetection,
  postProcessObjectDetectionResults,
  tensorToMatrix,
  prepareTextsForOwlVit,
} from "./inference_utils.mjs";

import { centerCrop, normalize, resize } from "Preprocess";

export class Color {
  /**
   * A colour, represented as an RGB value. Valid values for each are >= 0 and <= 255.
   *
   * @param {number} r - The amount of red in the color.
   * @param {number} g - The amount of green in the color.
   * @param {number} b - The amount of blue in the color.
   */
  constructor(r, g, b) {
    this.r = r;
    this.g = g;
    this.b = b;
  }

  toHex() {
    return `#${this.r.toString(16).padStart(2, "0")}${this.g
      .toString(16)
      .padStart(2, "0")}${this.b.toString(16).padStart(2, "0")}`;
  }
}

export class Position {
  /**
   * The two-dimensional coordinates indicating the location of something.
   *
   * @param {number} x - The x coordinate of the position.
   * @param {number} y - The y coordinate of the position.
   * @param {number} confidence - The confidence Guru has of the accuracy of this position.
   *        0.0 implies no confidence, 1.0 implies complete confidence.
   */
  constructor(x, y, confidence) {
    this.x = x;
    this.y = y;
    this.confidence = confidence !== undefined ? confidence : 1.0;
  }

  interpolate(other, factor) {
    /**
     * Interpolates this position with another, with the difference weight by a given factor.
     *
     * @param {Position} other - The other Position to interpolate between.
     * @param {number} factor - The scaling weight to apply to the difference in location between the two positions.
     * @returns {Position} The Position interpolated between this one and other.
     */
    return new Position(
      this.x + (other.x - this.x) * factor,
      this.y + (other.y - this.y) * factor,
      (this.confidence + other.confidence) / 2
    );
  }

  toImageCoords(width, height) {
    /**
     * Converts this position to image coordinates.
     *
     * @param {number} width - The width of the image.
     * @param {number} height - The height of the image.
     * @returns {Tuple} A tuple of length 2. The first element is the x coordinate in the image, the second is the y coordinate.
     */
    return [Math.floor(this.x * width), Math.floor(this.y * height)];
  }
}

export class Box {
  /**
   * A two-dimensional box, often indicating the bounds of something.
   *
   * @param {Position} top_left - The top-left corner of the box.
   * @param {Position} bottom_right - The bottom-right corner of the box.
   */
  constructor(top_left, bottom_right) {
    this.topLeft = top_left;
    this.bottomRight = bottom_right;
  }
}

/**
 * Keypoint is an enumeration of the names of the keypoints which can be found on objects.
 */
export const Keypoint = GURU_KEYPOINTS.reduce(
  (keypointEnum, keypointName, index) => {
    keypointEnum[keypointName] = index;
    return keypointEnum;
  },
  {}
);

/**
 * A single object present within a particular frame or image.
 */
export class FrameObject {
  /**
   * @param {string} objectType - The type of the object.
   * @param {Box} boundary - The bounding box of the object, defining its location within the frame.
   * @param {Dict} keypoints - The keypoints of the object.
   */
  constructor(objectType, boundary, keypoints) {
    this.objectType = objectType;
    this.boundary = boundary;
    this.keypoints = keypoints;
  }
}

const _createModelLoader = () => {
  const _cache = {};

  return (modelName) => {
    if (!ort.MODELS[modelName]) {
      throw new Error(`Model ${modelName} not found`);
    }

    if (!_cache[modelName]) {
      _cache[modelName] = new ort.InferenceSession(
        ort.MODELS[modelName]
      );
    }

    return _cache[modelName]
  }
};
const _loadModel = _createModelLoader();

/**
 * A single frame from a video, or image, on which Guru can perform inference.
 */
export class Frame {
  constructor(guruModels, image, hasAlpha) {
    this.poseModel = _loadModel("guru-rtmpose-img-256x192");
    this.personDetectionModel = _loadModel("tiny-yolov3");
    this.guruModels = guruModels;
    this.image = image;
    this.hasAlpha = hasAlpha;
  }

  /**
   * Find objects of a specific type within the video.
   *
   * @param {string or array of strings} objectTypes - The type of the object to find.
   *    Can either be a string, in which case objects of a single type will be found, or an array of strings, in which case multiple object types will be found.
   * @param {Object} attributes - The attributes of the object.
   * @param {boolean} keypoints - Flag indicating whether to include keypoints in the results. Defaults to true.
   * @return {List} A list of VideoObject instances matching the given criteria.
   */
  async findObjects(objectTypes, { attributes = {}, keypoints = true } = {}) {
    const objectBoundaries = await this._findObjectBoundaries(
      objectTypes,
      attributes
    );

    return await Promise.all(
      objectBoundaries.map(async (nextObject) => {
        let objectKeypoints = null;
        if (keypoints && nextObject.type === "person") {
          objectKeypoints = await this._findObjectKeypoints(
            nextObject.boundary
          );
        }

        return new FrameObject(
          nextObject.type,
          nextObject.boundary,
          objectKeypoints
        );
      })
    );
  }

  async _findObjectBoundaries(objectTypes, attributes) {
    if (objectTypes === "person" || objectTypes === "people") {
      return await this._findPeopleBoundaries();
    } else {
      const preprocessedFrame = preprocessImageForObjectDetection(
        this.image,
        768,
        768
      );
      const imageTensor = preprocessedImageToTensor(
        this.guruModels.ort(),
        preprocessedFrame
      );

      let objectBoundaries = [];
      const textBatches = prepareTextsForOwlVit(objectTypes);
      for (const textBatch of textBatches) {
        const textTensors = this.guruModels
          .tokenizer()
          .tokenize(textBatch, { padding: true, max_length: 16 });

        const model = this.guruModels.objectDetectionModel();
        const results = await model.session.run({
          pixel_values: imageTensor,
          input_ids: textTensors.input_ids,
          attention_mask: textTensors.attention_mask,
        });

        objectBoundaries = objectBoundaries.concat(
          postProcessObjectDetectionResults(results, textBatch).map(
            (nextObject) => {
              return {
                type: nextObject.class,
                boundary: new Box(
                  new Position(
                    nextObject.bbox[0],
                    nextObject.bbox[1],
                    nextObject.probability
                  ),
                  new Position(
                    nextObject.bbox[2],
                    nextObject.bbox[3],
                    nextObject.probability
                  )
                ),
              };
            }
          )
        );
      }
      return objectBoundaries;
    }
  }

  async _findPeopleBoundaries() {
    const [inputWidth, inputHeight] = [416, 416];
    const resizeWithPadZeros = (img) => {
      const dummyBbox = { x1: 0, y1: 0, x2: img.width - 1, y2: img.height - 1};
      return centerCrop(img, { inputWidth, inputHeight, boundingBox: dummyBbox, padding: 1.0 })
    }

    const resized = resizeWithPadZeros(this.image);
    const nchw = new Float32Array(resized.image.getData());
    const tensor = new ort.Tensor('float32', nchw, [1, 3, inputHeight, inputWidth]);
    const inputName = this.personDetectionModel.GetInputNames()[0]
    const results = await this.personDetectionModel.Run({
      [inputName]: tensor,
    });

    const outputMatrix = tensorToMatrix(results.dets);
    // TODO: return more than just the top result?
    const bbox = outputMatrix[0][0];
    const [x1, y1, x2, y2, score] = bbox;
    const topLeft = resized.reverseTransform({x: x1, y: y1})
    const bottomRight = resized.reverseTransform({x: x2, y: y2})
    return [
      {
        type: "person",
        boundary: new Box(
          new Position(topLeft.x, topLeft.y, score),
          new Position(bottomRight.x, bottomRight.y, score)
        ),
      },
    ];
  }

  async _findObjectKeypoints(boundingBox) {
    // TODO: read this from the model metadata
    const inputWidth = 192;
    const inputHeight = 256;

    const _arrayEq = (a, b) => {
      return (
        Array.isArray(a) &&
        Array.isArray(b) &&
        a.length === b.length &&
        a.every((val, index) => val === b[index])
      );
    };

    const { topLeft: { x: x1, y: y1 } } = boundingBox;
    const { bottomRight: { x: x2, y: y2 } } = boundingBox;
    const maxNormalizedRange = 1.1
    if ((x2 - x1) > maxNormalizedRange || (y2 - y1) > maxNormalizedRange) {
      throw new Error("boundingBox is not normalized");
    }
    const bbox = {
      x1: x1 * this.image.width,
      y1: y1 * this.image.height,
      x2: x2 * this.image.width,
      y2: y2 * this.image.height,
    };

    var cropped = centerCrop(this.image, { inputWidth, inputHeight, boundingBox: bbox });
    var normalized = normalize(cropped.image);
    const nchw = new Float32Array(normalized.getData());
    const tensor = new ort.Tensor("float32", nchw, [1, 3, 256, 192]);
    const result = this.poseModel.Run({ input: tensor });
    if (!_arrayEq(result.keypoints.dims, [1, 1, 17, 2])) {
      throw new Error(
        `Expected dims [1, 1, 17, 2] but got ${keypointsTensor.dims}`
      );
    }

    const keypoints = result.keypoints.data;
    const scores = result.scores.data;
    const j2p = {};
    for (let i = 0; i < scores.length; i++) {
      const _x = keypoints[i * 2]
      const _y = keypoints[i * 2 + 1]
      const { x, y } = cropped.reverseTransform({x: _x, y: _y});
      j2p[GURU_KEYPOINTS[i]] = {x, y, score: scores[i]};
    }
    return j2p
  }
}
