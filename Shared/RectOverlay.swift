import SwiftUI
import Vision

struct RectOverlay: View {

    let display: DisplayOptions

    let texts: [VNTextObservation]
    let rects: [VNRectangleObservation]
    let recogText: [VNRecognizedTextObservation]
    
    @State var hovered: (Int, Int?)? = nil
    
    var body: some View {
        GeometryReader{ geo in
            ZStack {
                if display.contains(.rects) {
                    ForEach(rects.indexed(), id: \.index) { (i, rect) in
                        let tbox = rect.scaleTo(geo)
                        Path(tbox)
                            .stroke(Color.green)
                    }
                }
                if display.contains(DisplayOptions.characters) {
                    ForEach(texts.indexed(), id: \.index) { (i, text) in
                        let isHovered = hovered?.0 == i
                        let tbox = text.scaleTo(geo)
                        Path(tbox)
                            .stroke(isHovered ? Color.white : Color.blue)
                        ForEach( (text.characterBoxes ?? []).indexed(), id: \.index) { (ii, charBox) in
                            let cbox = charBox.scaleTo(geo)
                            let isHovered = hovered?.0 == i && hovered?.1 == ii
                            
                            Path(cbox)
                                .stroke(isHovered ? Color.white : Color.red)
                        }
                    }
                }
                if display.contains(DisplayOptions.recognizedText) {
                    ForEach(recogText.indexed(), id: \.index) { (i, text: VNRecognizedTextObservation) in
                        let tbox = text.scaleTo(geo)
                        Path(tbox)
                            .stroke(Color.orange)
                        if let candidate = text.topCandidates(1).first {
                            Text(candidate.string)
                                .background(Color.white)
                                .foregroundColor(Color.black)
                                .rotationEffect(Angle(radians: tbox.rotation))
                                .position(x: tbox.center.x, y: tbox.center.y)
                        }
                    }
                    
                }
            }
        }.drawingGroup()
    }
}


