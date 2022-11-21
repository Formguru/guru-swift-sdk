import Foundation

public struct UploadResult {
  /**
    The overlays built for an uploaded video.
    This is a map of the type of the overlay to
    a URL from which that overlay can be downloaded.

    Note that not all overlay types will be generated for
    all uploads, dependent on client configuration.

    Each URL
  */
  public let overlays: [OverlayType: URL]
}
