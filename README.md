# GuruSwiftSDK

A Swift SDK for interacting with the Guru API.

# Getting Started

After adding the package as a dependency to your project, you will want to implement a controller like the following.
It is a simple controller that starts inference (in response to some button click) and shows each captured frame
to the user, in addition to rendering some of the inference result. Each section is described in more detail below.

```swift
import UIKit
import AVFoundation
import GuruSwiftSDK

class InferenceViewController: UIViewController {
  
  var inference: LocalVideoInference?
  @IBOutlet weak var imageView: UIImageView!
  var userLastFacing: UserFacing = UserFacing.other

  @IBAction func beingCapture(_ sender: AnyObject) {
    do {
        inference = try LocalVideoInference(
        consumer: self,
        cameraPosition: .front,
        source: "your-company-name",
        apiKey: "your-api-key"
      )
      
      Task {
        let videoId = try await inference!.start(activity: Activity.shoulder_flexion)
        print("Guru videoId is \(videoId)")
      }
    }
    catch {
      print("Unexpected error starting inference: \(error)")
    }
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    Task {
      try! await inference?.stop()
    }
  }
}

extension InferenceViewController: InferenceConsumer {
  
  func consumeAnalysis(analysis: Analysis) {
    // TODO: Implement this function.
  }
  
  func consumeFrame(frame: UIImage, inference: FrameInference?) {
    if (inference != nil) {
      let painter = InferencePainter(frame: frame, inference: inference!)
        .paintLandmarkConnector(from: InferenceLandmark.leftShoulder, to: InferenceLandmark.leftElbow)
        .paintLandmarkConnector(from: InferenceLandmark.leftElbow, to: InferenceLandmark.leftWrist)
        .paintLandmarkConnector(from: InferenceLandmark.leftShoulder, to: InferenceLandmark.leftHip)
        .paintLandmarkConnector(from: InferenceLandmark.leftHip, to: InferenceLandmark.leftKnee)
        .paintLandmarkConnector(from: InferenceLandmark.leftKnee, to: InferenceLandmark.leftAnkle)
        .paintLandmarkConnector(from: InferenceLandmark.rightShoulder, to: InferenceLandmark.rightElbow)
        .paintLandmarkConnector(from: InferenceLandmark.rightElbow, to: InferenceLandmark.rightWrist)
        .paintLandmarkConnector(from: InferenceLandmark.rightShoulder, to: InferenceLandmark.rightHip)
        .paintLandmarkConnector(from: InferenceLandmark.rightHip, to: InferenceLandmark.rightKnee)
        .paintLandmarkConnector(from: InferenceLandmark.rightKnee, to: InferenceLandmark.rightAnkle)
      
      let userFacing = inference!.userFacing()
      if (userFacing != UserFacing.other) {
        userLastFacing = userFacing
      }
      if (userLastFacing == UserFacing.left) {
        painter.paintLandmarkAngle(center: InferenceLandmark.rightShoulder, from: InferenceLandmark.rightHip, to: InferenceLandmark.rightElbow, clockwise: true)
      }
      else if (userLastFacing == UserFacing.right) {
        painter.paintLandmarkAngle(center: InferenceLandmark.leftShoulder, from: InferenceLandmark.leftHip, to: InferenceLandmark.leftElbow, clockwise: false)
      }
      
      imageView.image = painter.finish()
    }
    else {
      imageView.image = frame
    }
  }
}
```

The member variables of the controller are:

```swift
var inference: LocalVideoInference?
```
The LocalVideoInference is the main engine for interacting with the GuruSwiftSDK. You will use it to start and stop the inference.

```swift
@IBOutlet weak var imageView: UIImageView!
```
A handle to a `UIImageView` that we'll use to display each captured frame.

```swift
var userLastFacing: UserFacing = UserFacing.other
```
A variable to store the direction the user was facing in the previous frame.
We'll use this below to help us in cases where the inference confidence is low.

The `beingCapture` method would be called in response to the user clicking a button to start capturing.
```swift
inference = try LocalVideoInference(
  consumer: self,
  cameraPosition: .front,
  source: "your-company-name",
  apiKey: "your-api-key"
)

Task {
  let videoId = try await inference!.start(activity: Activity.shoulder_flexion)
  print("Guru videoId is \(videoId)")
}
```
It takes the source and apiKey, that will have been provided to you by Guru.
You also specify which phone camera to use. 
The `consumer` is a reference to the object that will be called as inference is
performed. It must implement the `InferenceConsumer` protocol.
The call to `start` will open the camera and begin making callbacks to the consumer.

The `viewWillDisappear` method is called when the user navigates away. It
ensures that the video capturing stops using `try! await inference?.stop()`.

The `InferenceConsumer` implementation has 2 important methods:
`func consumeFrame(frame: UIImage, inference: FrameInference?)` will be called 
for each frame captured. It will include the `frame`, which is the raw image itself,
and the `inference`, which is the information that has been analysed for the frame.
You can combine the two to draw additional information on the screen about what has
been captured. In the example above, it is drawing some of the keypoints to
create a skeleton and the angle between the hip, shoulder, and elbow. See the method
documentation in `InferencePainter` for more detail on each method.

The `func consumeAnalysis(analysis: Analysis)` callback is invoked less frequently,
and contains meta analysis about each of the frames seen so far. In here you can find
information about reps that have been counted, and any extra information about those
reps.

## Options
Following is a list of the configurable options for `LocalVideoInference`:
- `maxDuration`: The maximum amount of time, in seconds, that recording can run for. After this amount of time video capturing will automatically terminate (and the final analysis results sent to the callback). Default is 1 minute. Note that the longer a capture runs for, the longer the delay experienced in receiving new analysis results.
- `analysisPerSecond`: The maximum number of frames per second to send to the server for rep counting and analysis. Default is 8 per second. Lower values will results in lower bandwidth usage, at the expense of less accurate rep counting and analysis. Higher values will use more bandwidth, but give more accurate results. Generally speaking, the faster a movement is, the higher this value should be. Note that the video is recorded at 30 fps and so setting any value higher than this will have no affect.
- `recordTo`: If provided, the path to a file where the video will be recorded (in addition to also being streamed to the callback).

## Recording
If you wish to record the captured video then you can use an [AVAssetWriter](https://developer.apple.com/documentation/avfoundation/avassetwriter) to output each captured frame to a file. See [here](https://gist.github.com/yusuke024/b5cd3909d9d7f9e919291491f6b381f0#file-viewcontroller-swift-L82) for an example implementation.

If the video is recorded, you may choose to call `uploadVideo` after recording has been stopped.
By uploading your video to the Guru servers, overlay videos will be built for the video.
These overlay videos include rep counts and wireframes drawn over the top of the video.
The returned `UploadResult` will contain URLs from which the overlays can be downloaded.

# Requirements
This SDK requires iOS 15 or higher to function. It will throw a runtime error if
run on iOS >= 13 and < 15.

It has been tested for performance on iPhone 12 and higher. 
iPhone 11 will function, albeit with slower performance.

# Development
## How to rebuild generated model classes
If a new VipnasEndToEnd.mlpackage is available, then from root of package:
```bash
xcrun coremlc compile VipnasEndToEnd.mlpackage .
xcrun coremlc generate VipnasEndToEnd.mlpackage . --language Swift
```

## How to run tests
The easiest way is to run them from the `Test navigator` in XCode.
