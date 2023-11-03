import {
  arrayPeaks,
  arrayValuesLessThan,
  arrayVelocities,
  averageKeypointLocation,
  averageKeypointLocations,
  gaussianSmooth,
  GURU_KEYPOINTS,
  lowerCamelToSnakeCase,
  movingAverage,
  normalizeNumbers,
  preprocessedImageToTensor,
  preprocessImageForObjectDetection,
  postProcessObjectDetectionResults,
  tensorToMatrix,
  prepareTextsForOwlVit,
  snakeToLowerCamelCase,
} from "./inference_utils";

import { centerCrop, normalize, resize } from "guru/preprocess";
import { loadModelByName } from "guru/onnxruntime";

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
export const Keypoint = Object.freeze(GURU_KEYPOINTS.reduce((keypointEnum, keypointName, index) => {
  const lowerCamelCase = snakeToLowerCamelCase(keypointName);
  keypointEnum[lowerCamelCase] = keypointName;
  return keypointEnum;
}, {}));

/**
 * An enumeration of the ways an object can be facing, relative to the camera.
 */
export const ObjectFacing = Object.freeze({
  /**
   * Object facing the left-side of the frame.
   */
  Left: "left",
  /**
   * Object facing the right-side of the frame.
   */
  Right: "right",
  /**
   * Object facing towards the camera.
   */
  Toward: "toward",
  /**
   * Object facing away from the camera.
   */
  Away: "away",
  /**
   * Object facing towards the top of the frame.
   */
  Up: "up",
  /**
   * Object facing towards the bottom of the frame.
   */
  Down: "down",
  /**
   * Object direction unknown.
   */
  Unknown: "unknown",
});

/**
 * A single object present within a particular frame or image.
 */
export class FrameObject {

  /**
   * @param {string} objectId - The id of the object.
   * @param {string} objectType - The type of the object.
   * @param {number} timestamp - The timestamp of the frame.
   * @param {Box} boundary - The bounding box of the object, defining its location within the frame.
   * @param {Object.<string, Position>} keypoints - A map of the name of a keypoint, to its location within the frame.
   */
  constructor(objectId, objectType, timestamp, boundary, keypoints) {
    this._id = objectId;
    this.objectType = objectType;
    this.timestamp = timestamp;
    this.boundary = boundary;
    this.keypoints = keypoints;
  }

  /**
   * Get the location of a keypoint for the object at this frame.
   *
   * @param keypointName The name of the keypoint whose location will be fetched.
   * @returns {Position|undefined} The position of the keypoint, or undefined if unknown.
   */
  keypointLocation(keypointName) {
    const snake_case = lowerCamelToSnakeCase(keypointName);
    if (this.keypoints.hasOwnProperty(snake_case)) {
      return this.keypoints[snake_case];
    }
    else {
      return undefined;
    }
  }
}

const _createModelLoader = () => {
  const _cache = {};

  return (modelName) => {

    if (!_cache[modelName]) {
      _cache[modelName] = loadModelByName(modelName);
    }

    return _cache[modelName]
  }
};
const _loadModel = _createModelLoader();

/**
 * A single frame from a video, or image, on which Guru can perform inference.
 */
export class Frame {
  constructor(guruModels, image, timestamp, hasAlpha) {
    this.poseModel = _loadModel("pose");
    this.personDetectionModel = _loadModel("person_detection");
    this.guruModels = guruModels;
    this.image = image;
    this.timestamp = timestamp;
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
      objectBoundaries.map(async (nextObject, objectIndex) => {
        let objectKeypoints = null;
        if (keypoints && nextObject.type === "person") {
          objectKeypoints = await this._findObjectKeypoints(
            nextObject.boundary
          );
        }

        const frameObject = new FrameObject(
          `${nextObject.type}-${objectIndex.toString()}`,
          nextObject.type,
          this.timestamp,
          nextObject.boundary,
          objectKeypoints,
        );

        return frameObject;
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
    const topLeft = resized.reverseTransform({x: x1, y: y1});
    const bottomRight = resized.reverseTransform({x: x2, y: y2});
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
    const maxNormalizedRange = 2.0
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
      j2p[GURU_KEYPOINTS[i]] = {x, y, confidence: scores[i]};
    }
    return j2p
  }
}

/**
 * A class that provides general utility methods for analyzing outputs.
 */
export class GeneralAnalyzer {
  /**
   * Find the signals in a time-series array of numbers, by looking for valleys or peaks.
   *
   * @param {[number]} numbers - The time-series array of numbers in which signal will be found.
   * @param {boolean} findPeaks - True if the function should look for peaks, false if it should look for valleys.
   * @param {number} prominence - How prominent a peak must be before it is counted.
   * @param {number} sigma - How much smoothing to apply to the numbers before finding peaks. Higher values smooth more.
   * @returns {[object]} - An array of objects, each one having a start, middle, and end property, that holds the index
   *    into numbers of the boundaries of the peak or valley.
   */
  static signals(numbers, findPeaks, prominence, sigma) {  
    function findSignalBoundaries(signal, velocities, prevSignal, nextSignal) {
      const leftEdge = prevSignal + 1;
      let repStart = leftEdge;
      let seenPositive = false;  
      for (let i = signal - 1; i >= leftEdge; i--) {
        seenPositive = seenPositive || velocities[i] > 0;
        if (seenPositive && velocities[i] <= 0) {
          repStart = i + 1;
          break;
        }
      }
    
      const rightEdge = nextSignal - 1;
      let repEnd = rightEdge;
      let seenNegative = false;  
      for (let i = signal + 1; i < rightEdge; i++) {
        seenNegative = seenNegative || velocities[i] < 0;
        if (seenNegative && velocities[i] >= 0) {
          repEnd = i - 1;
          break;
        }
      }
    
      return [repStart, signal, repEnd];
    }  
  
    function peakProminences(x, peaks) {
      let prominences = new Float64Array(peaks.length);
      let leftMin, rightMin;
    
      for (let peakNr = 0; peakNr < peaks.length; peakNr++) {
        let peak = peaks[peakNr];
        let iMin = 0;
        let iMax = x.length - 1;
    
        if (!(iMin <= peak && peak <= iMax)) {
          throw new Error(`Peak ${peak} is not a valid index for 'x'.`);
        }
    
        let i = peak;
        leftMin = x[peak];
    
        while (iMin <= i && x[i] <= x[peak]) {
          if (x[i] < leftMin) {
            leftMin = x[i];
          }
          i--;
        }
    
        i = peak;
        rightMin = x[peak];
    
        while (i <= iMax && x[i] <= x[peak]) {
          if (x[i] < rightMin) {
            rightMin = x[i];
          }
          i++;
        }
    
        prominences[peakNr] = x[peak] - Math.max(leftMin, rightMin);
    
        if (prominences[peakNr] === 0) {
          console.warn(`Peak ${peakNr} has a prominence of 0`);
        }
      }
    
      return Array.from(prominences)
    }
    
    if (!findPeaks) {
      numbers = numbers.map((nextX) => 1.0 - nextX);
    }
  
    const smoothed = gaussianSmooth(numbers, sigma);
  
    const normalized = normalizeNumbers(smoothed);
  
    const possiblePeaks = arrayPeaks(normalized);
  
    const prominences = peakProminences(normalized, possiblePeaks);

    const peaks = possiblePeaks.filter((_, peakIndex) => {
      return prominences[peakIndex] >= prominence;
    });
  
    const velocities = arrayVelocities(normalized);
  
    return peaks.map((peak, index) => {
      const prevPeak = index === 0 ? -1 : peaks[index - 1];
      const nextPeak = index === peaks.length - 1 ? velocities.length - 1 : peaks[index + 1];
      const boundaries = findSignalBoundaries(peak, velocities, prevPeak, nextPeak);
  
      return {
        start: boundaries[0],
        middle: boundaries[1],
        end: boundaries[2],
      };
    });
  }

  static estimateStartAndEndTrim(frameObjects, threshold = 0.75) {
    function calculateRunningDifference(frameObjects, midXY) {
      const runningDiff = frameObjects.map((frameObject) => {
        return Object.keys(frameObject.keypoints).map((keypointName, keypointIndex) => {
          const location = frameObject.keypointLocation(keypointName);
          return Math.sqrt(
            Math.pow(location.x - midXY[keypointIndex][0], 2) +
            Math.pow(location.y - midXY[keypointIndex][1], 2)
          );
        });
      });
      return runningDiff.map((frame) => frame.reduce((acc, val) => acc + val, 0));
    }
    
    function calculateCutoff(runningDiff, threshold) {
      const sortedArr = runningDiff.slice().sort((a, b) => a - b);
      const index = (sortedArr.length - 1) * threshold;
      const lower = Math.floor(index);
      const fraction = index - lower;
    
      if (lower + 1 < sortedArr.length) {
        return sortedArr[lower] + fraction * (sortedArr[lower + 1] - sortedArr[lower]);
      } else {
        return sortedArr[lower];
      }
    }
    
    const numFrames = frameObjects.length;
    const midXY = averageKeypointLocations(
      frameObjects,
      Math.floor(frameObjects.length / 3),
      Math.floor((2 * frameObjects.length) / 3),
    );
    const runningDiff = calculateRunningDifference(frameObjects, midXY);
    const cutoff = calculateCutoff(runningDiff, threshold);
    const slidingDiff = movingAverage(runningDiff, 4);
  
    const pred = arrayValuesLessThan(slidingDiff, cutoff);
    if (pred.length < 2) {
      return [0, numFrames - 1];
    }
  
    let start = pred[0];
    let end = pred[pred.length - 1];
    if (start > Math.floor(numFrames / 3) || end < Math.floor((2 * numFrames) / 3)) {
      start = 0;
      end = numFrames - 1;
    }
  
    return [
      frameObjects[start].timestamp,
      frameObjects[frameObjects.length - 1].timestamp - frameObjects[end].timestamp,
    ];
  }
}

/**
 * Class containing utility methods for performing analysis on human movement videos.
 */
export class MovementAnalyzer {
  /**
   * Calculate the angle (in degrees) between two keypoints on a person frame by assessing
   * the slope formed by their positions. This method is useful for determining the relative
   * orientation of two keypoints and can be used in analyzing postures, movements, or positions.
   *
   * The returned angle is based on the inverse tangent of the slope (rise over run)
   * formed by the vertical and horizontal distances between the two keypoints.
   *
   * @param {FrameObject} personFrame - The frame data containing keypoints information.
   * @param {Keypoint} keypoint1 - The first keypoint used for angle calculation.
   * @param {Keypoint} keypoint2 - The second keypoint used for angle calculation.
   * @returns {number} - The calculated angle in degrees between the two keypoints.
   */
  static angleBetweenKeypoints(personFrame, keypoint1, keypoint2) {
    const keypoint1Location = personFrame.keypointLocation(keypoint1);
    const keypoint2Location = personFrame.keypointLocation(keypoint2);
    const distance =
      (keypoint2Location.y - keypoint1Location.y) /
      (keypoint2Location.x - keypoint1Location.x);
    return (Math.atan(distance) * 180) / Math.PI;
  }  

  /**
   * Determines which direction the person is mostly facing throughout the video.
   *
   * @param {[FrameObject]} personFrames - The frames of the person.
   * @return {ObjectFacing} The direction that the person is mostly facing throughout the video.
   */
  static personMostlyFacing(personFrames) {
    if (this.personMostlyStanding(personFrames)) {
      const nose = averageKeypointLocation(personFrames, Keypoint.nose);
      const leftHip = averageKeypointLocation(personFrames, Keypoint.leftHip);
      const rightHip = averageKeypointLocation(personFrames, Keypoint.rightHip);

      if (nose.x < leftHip.x && nose.x < rightHip.x) {
        return ObjectFacing.Left;
      }
      else if (nose.x > leftHip.x && nose.x > rightHip.x) {
        return ObjectFacing.Right;
      }
      else if (nose.x > rightHip.x && nose.x < leftHip.x) {
        return ObjectFacing.Toward;
      }
      else {
        return ObjectFacing.Unknown;
      }
    }
    else {
      const leftShoulder = averageKeypointLocation(personFrames, Keypoint.leftShoulder);
      const rightShoulder = averageKeypointLocation(personFrames, Keypoint.rightShoulder);
      const leftWrist = averageKeypointLocation(personFrames, Keypoint.leftWrist);
      const rightWrist = averageKeypointLocation(personFrames, Keypoint.rightWrist);

      if (leftShoulder.y < leftWrist.y && rightShoulder.y < rightWrist.y) {
        return ObjectFacing.Down;
      }
      else if (leftShoulder.y > leftWrist.y && rightShoulder.y > rightWrist.y) {
        return ObjectFacing.Up;
      }
      else {
        return ObjectFacing.Unknown;
      }
    }
  }

  /**
   * Determines if the person is mostly standing upright throughout the video or not.
   * If false, then they are likely lying down.
   *
   * @param {[FrameObject]} personFrames - The frames of the person.
   * @return {boolean} True if the person is mostly standing up in the video.
   */
  static personMostlyStanding(personFrames) {
    const leftShoulder = averageKeypointLocation(personFrames, Keypoint.leftShoulder);
    const leftHip = averageKeypointLocation(personFrames, Keypoint.leftHip);
    const rightShoulder = averageKeypointLocation(personFrames, Keypoint.rightShoulder);
    const rightHip = averageKeypointLocation(personFrames, Keypoint.rightHip);
    const leftKnee = averageKeypointLocation(personFrames, Keypoint.leftKnee);
    const rightKnee = averageKeypointLocation(personFrames, Keypoint.rightKnee);

    const personHorizontal = (
      (leftShoulder.x > leftHip.x) &&
      (rightShoulder.x > rightHip.x) &&
      (leftHip.x > leftKnee.x) &&
      (rightHip.x > rightKnee.x)
    ) || (
      (leftShoulder.x < leftHip.x) &&
      (rightShoulder.x < rightHip.x) &&
      (leftHip.x < leftKnee.x) &&
      (rightHip.x < rightKnee.x)
    );
    return !personHorizontal;
  }  

  /**
   * Find the repetitions of a movement a person is performing, by measuring
   * the distance over time between two keypoints. For example, if a person
   * is performing a squat, then measuring the distance between hips and ankles
   * will give a good signal for identifying squat reps.
   *
   * By default this function will identify when the two keypoints get closer together
   * and count that as a rep. If reps should instead be counted by the keypoints getting
   * further apart, set
   *
   * @param {[FrameObject]} personFrames - The location of the person in each frame of the video.
   * @param {Keypoint} keypoint1 - The first keypoint to measure between.
   * @param {Keypoint} keypoint2 - The second keypoint to measure between.
   * @param {boolean} keypointsContract - True if a rep is identified as the distance between the keypoints contracting.
   *    Set to false if the keypoint distance expands during a rep. Defaults true.
   * @param {number} threshold - The distance required between the keypoints before a rep is counted.
   *    This number is abstract, it does not translate directly to pixel distance.
   * @param {number} smoothing - How much smoothing should be applied to keypoints before reps are counted.
   *    Higher values will apply more smoothing, which can help with lower quality or obscured videos.
   * @param {number} ignoreStartMs - The number of milliseconds to ignore at the start of the video when counting reps.
   *    If null, attempts to estimate the start time. Default null.
   * @param {number} ignoreEndMs - The number of milliseconds to ignore at the end of the video when counting reps.
   *    If null, attempts to estimate the end time. Default null.
   * @returns {[]} - An array of objects, each one having a start, middle, and end property that is
   *    the millisecond timestamp of the boundaries for that rep.
   */
  static repsByKeypointDistance(
    personFrames, 
    keypoint1, 
    keypoint2, { 
      keypointsContract = true,
      threshold = 0.2,
      smoothing = 2.0,
      ignoreStartMs = null,
      ignoreEndMs = null,
    } = {}) {
    if (!ignoreStartMs || !ignoreEndMs) {
      const [estimatedStartMs, estimatedEndMs] = GeneralAnalyzer.estimateStartAndEndTrim(personFrames);
      if (!ignoreStartMs) {
        ignoreStartMs = estimatedStartMs;
      }
      if (!ignoreEndMs) {
        ignoreEndMs = estimatedEndMs;
      }
    }

    const start = ignoreStartMs;
    const end = Math.max(
      Math.max(...personFrames.map((frame) => frame.timestamp)) - ignoreEndMs, 
      start + 1
    );
    let firstFrameIndex = 0;
    const jointDistances = personFrames.map((frameObject) => {
      if (frameObject.timestamp < start) {
        ++firstFrameIndex;
        return null;
      }
      else if (frameObject.timestamp > end) {
        return null;
      }

      const keypoint1Location = frameObject.keypointLocation(keypoint1);
      const keypoint2Location = frameObject.keypointLocation(keypoint2);

      if (keypoint1Location && keypoint2Location) {
        return Math.abs(keypoint1Location.y - keypoint2Location.y);
      }
      else {
        return null;
      }
    }).filter((distance) => distance !== null);

    const signals = GeneralAnalyzer.signals(jointDistances, !keypointsContract, threshold, smoothing);

    return signals.map((signal) => {
      return {
        startFrame: personFrames[signal.start + firstFrameIndex],
        middleFrame: personFrames[signal.middle + firstFrameIndex],
        endFrame: personFrames[signal.end + firstFrameIndex],
      };
    });
  }
}


/**
 * A class that knows the output of inference across the video and is capable of
 * computing analysis based on it.
 */
export class VideoAnalysis {

  constructor(frameResults) {
    this.frameResults = frameResults;
    this.length = frameResults.length;
  }

  filter(callback) {
    const filteredArray = [];
    for (let i = 0; i < this.length; i++) {
      if (callback(this.frameResults[i], i, this)) {
        filteredArray.push(this.frameResults[i]);
      }
    }
    return new VideoAnalysis(filteredArray);
  }

  find(callback) {
    for (let i = 0; i < this.length; i++) {
      if (callback(this.frameResults[i], i, this)) {
        return this.frameResults[i];
      }
    }
    return undefined;
  }

  forEach(callback) {
    for (let i = 0; i < this.length; i++) {
      callback(this.frameResults[i], i, this);
    }
  }

  get(index) {
    if (index < 0 || index >= this.length) {
      return undefined; // Out of bounds
    }
    return this.frameResults[index];
  }

  indexOf(searchElement, fromIndex = 0) {
    for (let i = fromIndex; i < this.length; i++) {
      if (this.frameResults[i] === searchElement) {
        return i;
      }
    }
    return -1;
  }

  map(callback) {
    const mappedArray = [];
    for (let i = 0; i < this.length; i++) {
      const mappedValue = callback(this.frameResults[i], i, this);
      mappedArray.push(mappedValue);
    }
    return mappedArray;
  }

  resultArray() {
    return this.frameResults.map((frameResult) => frameResult.returnValue);
  }

  reduce(callback, initialValue) {
    let accumulator = initialValue === undefined ? this.frameResults[0] : initialValue;
    for (let i = initialValue === undefined ? 1 : 0; i < this.length; i++) {
      accumulator = callback(accumulator, this.frameResults[i], i, this);
    }
    return accumulator;
  }

  slice(start = 0, end = this.length) {
    const slicedArray = [];
    start = Math.max(start >= 0 ? start : this.length + start, 0);
    end = Math.min(end >= 0 ? end : this.length + end, this.length);
    for (let i = start; i < end; i++) {
      slicedArray.push(this.frameResults[i]);
    }
    return new VideoAnalysis(slicedArray);
  }

  toJSON() {
    return this.frameResults;
  }

  toString() {
    return JSON.stringify(this.toJSON());
  }
}


export class FrameObjectRegistry {
  constructor(frameObjects) {
    this.idToFrameObjects = {};

    (frameObjects || []).forEach((frameObject) => {
      if (!this.idToFrameObjects.hasOwnProperty(frameObject._id)) {
        this.idToFrameObjects[frameObject._id] = [];
      }
      this.idToFrameObjects[frameObject._id].push(frameObject);
    });

    Object.values(this.idToFrameObjects).forEach(array => 
      array.sort((a, b) => a.timestamp - b.timestamp)
    );
  }

  registerFrameObject(frameObject) {
    if (!this.idToFrameObjects.hasOwnProperty(frameObject._id)) {
      this.idToFrameObjects[frameObject._id] = [];
    }

    this.idToFrameObjects[frameObject._id].push(frameObject);

    this.idToFrameObjects[frameObject._id].sort((a, b) => {
      return a.timestamp - b.timestamp;
    });
  }

  /**
   * Get the FrameObject before and the FrameObject after a given timestamp.
   *
   * @param objectId The id of the object.
   * @param timestamp The timestamp to fetch around.
   * @return {[FrameObject, FrameObject]} The FrameObjects before and after the timestamp.
   */
  frameObjectsAroundTimestamp(objectId, timestamp) {
    const frameObjects = this.frameObjects(objectId);

    if (frameObjects.length === 0) {
      return null;
    }
    if (frameObjects.length === 1) {
      return [frameObjects[0], frameObjects[0]];
    }

    let prevFrameObject, nextFrameObject;
    frameObjects.every((frameObject) => {
      prevFrameObject = nextFrameObject;
      nextFrameObject = frameObject;

      return frameObject.timestamp < timestamp;
    });

    if (!prevFrameObject) {
      prevFrameObject = nextFrameObject;
    }

    return [prevFrameObject, nextFrameObject];
  };

  /**
   * Gets all of the FrameObjects for a particular object.
   *
   * @param {string} objectId The id of the object
   * @return {[FrameObject]} The FrameObjects for the object. Empty if object is unknown.
   */
  frameObjects(objectId) {
    if (!this.idToFrameObjects.hasOwnProperty(objectId)) {
      return [];
    }
    else {
      return this.idToFrameObjects[objectId]
        .map((frameObject) => this._deserializeRegistryObject(frameObject));
    }
  }

  frameObjectsForType(objectType) {
    return this.objectIds(objectType).map((objectId) => this.frameObjects(objectId));
  }

  objectIds(objectType) {
    return Object.keys(this.idToFrameObjects).filter((objectId) => {
      return this.idToFrameObjects[objectId][0].objectType === objectType;
    });
  }

  _deserializeRegistryObject(registryObject) {
    const keypoints = {};
    for (const keypoint in registryObject.keypoints) {
      keypoints[keypoint] = new Position(
        registryObject.keypoints[keypoint].x,
        registryObject.keypoints[keypoint].y,
        registryObject.keypoints[keypoint].confidence,
      );
    }

    return new FrameObject(
      registryObject._id,
      registryObject.objectType,
      registryObject.timestamp,
      new Box(
        new Position(
          registryObject.boundary.topLeft.x,
          registryObject.boundary.topLeft.y,
          registryObject.boundary.topLeft.confidence,
        ),
        new Position(
          registryObject.boundary.bottomRight.x,
          registryObject.boundary.bottomRight.y,
          registryObject.boundary.bottomRight.confidence,
        ),
      ),
      keypoints,
    )
  }
}