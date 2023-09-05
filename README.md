# GuruSwiftSDK

A Swift SDK for interacting with the Guru API.

# Getting Started

After adding the package as a dependency to your project, you will want to implement a controller like the following.
It is a simple controller that opens the camera feed and runs an AI schema against each frame to perform some analysis. 
This example assumes you have already built an AI schema on the [Guru Console](https://console.getguru.fitness), so create
one there if you haven't already.
Each section is described in more detail below.

```swift
import UIKit
import AVFoundation
import GuruSwiftSDK

class SkeletonSDKViewController: UIViewController {
  
  let session = AVCaptureSession()
  var guruVideo: GuruVideo?
  var latestInference: GuruAnalysis = GuruAnalysis(result: nil, processResult: [:])

  @IBOutlet weak var imageView: UIImageView!
  
  @IBAction func start(_ sender: Any) {
    // Setup the camera
    session.sessionPreset = .vga640x480
    let device =  AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: AVCaptureDevice.Position.front)
    let input = try! AVCaptureDeviceInput(device: device!)
    session.addInput(input)    
    let output = AVCaptureVideoDataOutput()
    output.alwaysDiscardsLateVideoFrames = true
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: kCVPixelFormatType_32BGRA]
    output.setSampleBufferDelegate(self, queue: DispatchQueue.main)
    session.addOutput(output)
    
    // Create the GuruVideo object
    Task { @MainActor in
      self.guruVideo = try await GuruVideo(
          apiKey: "YOUR-API-KEY",
          schemaId: "SCHEMA-ID"
      )
    }
    
    // Start the camera feed
    DispatchQueue.global(qos: .userInitiated).async {
      self.session.startRunning()
    }
  }
  
  func imageOrientation() -> UIImage.Orientation {
      let curDeviceOrientation = UIDevice.current.orientation
      var exifOrientation: UIImage.Orientation
      switch curDeviceOrientation {
          case UIDeviceOrientation.portraitUpsideDown:
              exifOrientation = .left
          case UIDeviceOrientation.landscapeLeft:
              exifOrientation = .upMirrored
          case UIDeviceOrientation.landscapeRight:
              exifOrientation = .down
          case UIDeviceOrientation.portrait:
              exifOrientation = .up
          default:
              exifOrientation = .up
      }
      return exifOrientation
  }
  
  private func bufferToImage(imageBuffer: CMSampleBuffer) -> UIImage? {
    guard let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(imageBuffer) else {
      return nil
    }

    return UIImage(
      ciImage: CIImage(cvPixelBuffer: imageBuffer),
      scale: 1.0,
      orientation: imageOrientation()
    )
  }
  
  private func updateInference(image: UIImage) async {
    self.latestInference = guruVideo!.newFrame(frame: image)
  }
}

extension SkeletonSDKViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    let image: UIImage? = bufferToImage(imageBuffer: sampleBuffer)
      
    if (image != nil && guruVideo != nil) {
      DispatchQueue.global(qos: .userInteractive).async {
        Task.detached {
          // run the inference from the AI schema
          await self.updateInference(image: image!)
        }
      }
      
      // render the result of the inference onto the image
      let overlaidImage = guruVideo!.renderFrame(frame: image!, analysis: self.latestInference)
      
      imageView.image = overlaidImage
      
      // TODO: If you want to do anything else with this frame,
      // like writing the results to your own API,
      // this is the place to do it!
    }
  }
}
```

The `start` method, which would be called in response to some button click, does 3 things:
1. Sets up the camera. There are many ways to do this in iOS, shown here is one simple way.
2. Creates the `GuruVideo` object. This is the primary object for interfacing with the Guru SDK.
You will want to create one of these per video recorded. You provide to it your API Key, and the ID
of your Schema. Both of these values can be retrieved from the `Deploy` tab on the Guru Console.
3. Starts the camera feed.

After this, the `captureOutput` method will start receiving a stream of images from the camera.
For each image, it passes it to the `newFrame` method on the `GuruVideo` instance. This method
will run the AI Schema's `Process` and `Analyze` code against the frame, and return the result.

It then also passes the result to the `renderFrame` method, which will run the `Render` code from
the AI schema. This will produce a new image, with bounding boxes, skeletons, or whatever else the
AI schema defines drawn onto it.

# Requirements
This SDK requires iOS 15 or higher to function. It will throw a runtime error if
run on iOS >= 13 and < 15.

It has been tested for performance on iPhone 12 and higher. 
iPhone 11 will function, albeit with slower performance.
