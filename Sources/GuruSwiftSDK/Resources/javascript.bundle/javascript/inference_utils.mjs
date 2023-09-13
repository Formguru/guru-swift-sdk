export const GURU_KEYPOINTS = [
    "nose",
    "left_eye",
    "right_eye",
    "left_ear",
    "right_ear",
    "left_shoulder",
    "right_shoulder",
    "left_elbow",
    "right_elbow",
    "left_wrist",
    "right_wrist",
    "left_hip",
    "right_hip",
    "left_knee",
    "right_knee",
    "left_ankle",
    "right_ankle",
    "left_heel",
    "right_heel",
    "left_toe",
    "right_toe",
  ];
  
  function centerToCornersFormat([centerX, centerY, width, height]) {
    return [
      centerX - width / 2,
      centerY - height / 2,
      centerX + width / 2,
      centerY + height / 2
    ];
  }
  
  function cropImage(imageData, boundingBox) {
    const { data, width } = imageData;
    const x = Math.round(boundingBox.topLeft.x * imageData.width);
    const y = Math.round(boundingBox.topLeft.y * imageData.height);
    const bboxWidth = Math.round(boundingBox.bottomRight.x * imageData.width - x);
    const bboxHeight = Math.round(boundingBox.bottomRight.y* imageData.height - y);
    const bytesPerPixel = 4;
  
    // Create a new Uint8ClampedArray for the cropped image data
    const croppedData = new Uint8ClampedArray(bboxWidth * bboxHeight * bytesPerPixel);
  
    // Iterate over the rows and columns of the bounding box
    for (let row = 0; row < bboxHeight; row++) {
      const srcStartIndex = ((y + row) * width + x) * bytesPerPixel;
      const destStartIndex = Math.min(row * bboxWidth * bytesPerPixel, croppedData.length - 1);
  
      // Copy the pixels from the source image data to the cropped image data
      croppedData.set(data.subarray(srcStartIndex, srcStartIndex + bboxWidth * bytesPerPixel), Math.min(destStartIndex, croppedData.length - 1));
    }
  
    return {
      data: croppedData,
      width: bboxWidth,
      height: bboxHeight,
    };
  }
  
  export function descaleCoords(x, y, originalWidth, originalHeight, scaledWidth, scaledHeight) {
    return [
      x * (originalWidth / scaledWidth) / originalWidth,
      y * (originalHeight / scaledHeight) / originalHeight,
    ];
  }
  
  function toRGBFloatArray(imageData) {
    const increment = 4;
    const filteredArray = new Float32Array(imageData.data.length / increment * 3);
    let j = 0;
    for (let i = 0; i < imageData.data.length; i += increment) {
      filteredArray[j++] = imageData.data[i];
      filteredArray[j++] = imageData.data[i + 1];
      filteredArray[j++] = imageData.data[i + 2];
    }
    return filteredArray;
  }
  
  /**
   * Determines the most likely class/prediction for each box.
   *
   * @param matrix A [X, Y, 1] matrix, where X is the number of possible prediction classes,
   *  and Y is the number of boxes.
   * @param bboxes Array of objects of size Y, corresponding to the bounding box for each prediction.
   *  @param classes Array of strings that are the classes input to the model for detection.
   * @param threshold The likelihood over which predictions will be counted.
   * @returns An array of length Y, that contains objects that each have a 'probability' field and a
   *  'labelIndex' field. The former is the probability of the highest likelihood prediction for that box,
   *  and labelIndex is the index of the possible classes which that probability is for.
   */
  function mostLikelyClass(matrix, bboxes, classes, threshold) {
    const mostLikelyClasses = [];
  
    const matrixDimensions = matrix.size();
    for (let i = 0; i < matrixDimensions[1]; ++i) {
      let highestProbability = -10000000;
      let highestProbabilityIndex = highestProbability;
      for (let j = 0; j < matrixDimensions[0]; ++j) {
        const nextValue = matrix[j][i][0];
        if (nextValue > highestProbability) {
          highestProbability = nextValue;
          highestProbabilityIndex = j;
        }
      }
  
      highestProbability = sigmoid(highestProbability);
      if (highestProbability > threshold) {
        mostLikelyClasses.push({
          probability: highestProbability,
          class: classes[highestProbabilityIndex],
          bbox: bboxes[i],
        });
      }
    }
  
    return mostLikelyClasses;
  }
  
  function normalizeImageData(imageData, mean = [0, 0, 0], std = [1, 1, 1]) {
    const data = imageData.data;
    const len = data.length;
  
    const bytesPerPixel = 4;
    const normalizedArray = new Float32Array(len / bytesPerPixel * 3);
    let j = 0;
    for (let i = 0; i < len; i += bytesPerPixel) {
      let r = data[i];
      let g = data[i + 1];
      let b = data[i + 2];
  
      if (r > 1.0) {
        r /= 255.0;
      }
      if (g > 1.0) {
        g /= 255.0;
      }
      if (b > 1.0) {
        b /= 255.0;
      }
  
      normalizedArray[j++] = (r - mean[0]) / std[0];
      normalizedArray[j++] = (g - mean[1]) / std[1];
      normalizedArray[j++] = (b - mean[2]) / std[2];
    }
  
    return normalizedArray;
  }
  
  function scaleImageData(imageData, targetWidth, targetHeight) {
    return scaleImage(
      imageData.data,
      imageData.width,
      imageData.height,
      targetWidth,
      targetHeight
    );
  }
  
  function scaleImage(image, sourceWidth, sourceHeight, targetWidth, targetHeight, scalingFactor = 1.0) {
    const scaleX = sourceWidth / targetWidth;
    const scaleY = sourceHeight / targetHeight;
  
    const bytesPerPixel = 4;
    const targetData = new Float32Array(targetWidth * targetHeight * bytesPerPixel);
  
    for (let y = 0; y < targetHeight; y++) {
      for (let x = 0; x < targetWidth; x++) {
        const sourceX = Math.floor(x * scaleX);
        const sourceY = Math.floor(y * scaleY);
  
        const sourceIndex = (sourceY * sourceWidth + sourceX) * bytesPerPixel;
        const targetIndex = (y * targetWidth + x) * bytesPerPixel;
  
        for (let i = 0; i < bytesPerPixel; i++) {
          targetData[targetIndex + i] = image[sourceIndex + i] * scalingFactor;
        }
      }
    }
  
    return {
      data: targetData,
      width: targetWidth,
      height: targetHeight,
    };
  }
  
  function transposeImageData(imageArray, width, height) {
    const channels = 3;
    const transposed = new Float32Array(channels * height * width);
  
    let transposedIndex = 0;
    for (let i = 0; i < imageArray.length; i += 3) {
      transposed[transposedIndex++] = imageArray[i];
    }
    for (let i = 1; i < imageArray.length; i += 3) {
      transposed[transposedIndex++] = imageArray[i];
    }
    for (let i = 2; i < imageArray.length; i += 3) {
      transposed[transposedIndex++] = imageArray[i];
    }
  
    return transposed;
  }
  
  function sigmoid(x) {
    return 1 / (1 + Math.exp(-x));
  }
  
  export function postProcessObjectDetectionResults(results, labels, threshold = 0.01) {
    const numBoxes = results.logits.dims[1];
    const bboxMatrix = tensorToMatrix(results.pred_boxes);
    const bboxes = [];
    for (let i = 0; i < numBoxes; ++i) {
      bboxes.push(centerToCornersFormat([
        bboxMatrix[0][i][0],
        bboxMatrix[0][i][1],
        bboxMatrix[0][i][2],
        bboxMatrix[0][i][3],
      ]));
    }
  
    return mostLikelyClass(tensorToMatrix(results.logits), bboxes, labels, threshold);
  }
  
  export const preprocessImageForObjectDetection = (imageData, modelWidth, modelHeight) => {
    const resized = scaleImage(
      imageData.data,
      imageData.width, imageData.height,
      modelWidth, modelHeight,
      0.00392156862745098,
    );
  
    const normalized = normalizeImageData(
      resized,
      [0.48145466, 0.4578275, 0.40821073],
      [0.26862954, 0.26130258, 0.27577711],
    );
  
    const transposedImage = transposeImageData(normalized, modelWidth, modelHeight);
  
    return {
      image: transposedImage,
      newWidth: modelWidth,
      newHeight: modelHeight,
    };
  };
  
  export const preprocessImageForPersonDetection = (imageData, modelWidth, modelHeight) => {
    const resized = scaleImageData(imageData, modelWidth, modelHeight);
    const rgbImage = toRGBFloatArray(resized);
    const transposedImage = transposeImageData(rgbImage, modelWidth, modelHeight);
  
    return {
      image: transposedImage,
      newWidth: modelWidth,
      newHeight: modelHeight,
    };
  };
  
  export function preprocessedImageToTensor(ort, preprocessedFrame) {
    return new ort.Tensor(
      'float32',
      preprocessedFrame.image,
      [1, 3, preprocessedFrame.newHeight, preprocessedFrame.newWidth]
    );
  }
  
  
  /**
   * The text batch size for OWL-ViT is 2, so groups the inputs into pairs
   * so that they can be run most efficiently.
   *
   * @param textInputs Array of strings of the items to look for.
   * @returns The Array of Pairs.
   */
  export function prepareTextsForOwlVit(textInputs) {
    const paddingValue = "nothing";
    if (Array.isArray(textInputs)) {
      if (textInputs.length % 2 > 0) {
        textInputs.push(paddingValue);
      }
  
      const pairs = [];
      for (let i = 0; i < textInputs.length; i += 2) {
        pairs.push([textInputs[i], textInputs[i + 1]]);
      }
      return pairs;
    }
    else {
      return [[textInputs, paddingValue]];
    }
  }
  
  export function tensorToMatrix(tensor) {
    const dataArray = Array.from(tensor.data);
  
    function reshapeArray(array, shape) {
      if (shape.length === 0) {
        return array.shift();
      }
      const size = shape.shift();
      const subArray = [];
      for (let i = 0; i < size; i++) {
        subArray.push(reshapeArray(array, shape.slice()));
      }
      return subArray;
    }
  
    const dimensions = [...tensor.dims];
    const matrix = reshapeArray(dataArray, tensor.dims);
    matrix.size = function() {
      return dimensions;
    };
    return matrix;
  }