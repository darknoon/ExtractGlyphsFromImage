import Vision
import Foundation

@MainActor class VisionAPI: ObservableObject {
    
    var error: Error?
    
    var detectRects: Bool = true
    var detectText: Bool = true
    var recognizeText: Bool = true
    
    @Published var texts: [VNTextObservation]?
    @Published var rects: [VNRectangleObservation]?
    @Published var recogTexts: [VNRecognizedTextObservation]?

    lazy var rectangleDetectionRequest: VNDetectRectanglesRequest = {
        let rectDetectRequest = VNDetectRectanglesRequest()
        // Customize & configure the request to detect only certain rectangles.
        rectDetectRequest.maximumObservations = 8 // Vision currently supports up to 16.
        rectDetectRequest.minimumConfidence = 0.6 // Be confident.
        rectDetectRequest.minimumAspectRatio = 0.1 // height / width
        return rectDetectRequest
    }()
    
    lazy var textDetectionRequest: VNDetectTextRectanglesRequest = {
        let textDetectRequest = VNDetectTextRectanglesRequest()
        // Tell Vision to report bounding box around each character.
        textDetectRequest.reportCharacterBoxes = true
        return textDetectRequest
    }()

    lazy var textRecognitionRequest: VNRecognizeTextRequest = {
        let textDetectRequest = VNRecognizeTextRequest()
        textDetectRequest.minimumTextHeight = 1/200
        return textDetectRequest
    }()
    
    fileprivate func createVisionRequests() -> [VNRequest] {
        
        // Create an array to collect all desired requests.
        var requests: [VNRequest] = []
        
        // Create & include a request if and only if switch is ON.
        if detectRects {
            requests.append(self.rectangleDetectionRequest)
        }
        if detectText {
            requests.append(self.textDetectionRequest)
        }
        if recognizeText {
            requests.append(self.textRecognitionRequest)
        }
        
        // Return grouped requests as a single array.
        return requests
    }
    
    func doVisionRequest(image: CGImage, orientation: CGImagePropertyOrientation = .up) async {
        let requests = createVisionRequests()
        // Create a request handler.
        let imageRequestHandler =
        VNImageRequestHandler(cgImage: image,
                              orientation: orientation,
                              options: [:])
        do {
            try imageRequestHandler.perform(requests)
        } catch {
            print("Failed to perform image request: \(error)")
            self.error = error
            return
        }
        await MainActor.run{
            for request in requests {
                switch request {
                case let request as VNRecognizeTextRequest:
                    recogTexts = request.results
                case let request as VNDetectTextRectanglesRequest:
                    texts = request.results
                case let request as VNDetectRectanglesRequest:
                    rects = request.results
                default:
                    fatalError("Request completion of unexpected type: \(request.className)")
                }
            }
        }
    }
}
