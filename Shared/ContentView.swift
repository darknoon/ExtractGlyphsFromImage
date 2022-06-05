//
//  ContentView.swift
//  Shared
//
//  Created by Andrew Pouliot on 6/4/22.
//

import SwiftUI
import UniformTypeIdentifiers
import Algorithms
import Vision

extension Path {
    
    init(_ tbox: PointBox) {
        self.init{
            $0.addBox(tbox)
        }
    }
    mutating func addBox(_ tbox: PointBox) {
        addLines([tbox.topLeft, tbox.topRight,
                  tbox.topRight, tbox.bottomRight,
                  tbox.bottomRight, tbox.bottomLeft,
                  tbox.bottomLeft, tbox.topLeft])

    }
}

protocol BoxCorners {
    var topLeft: CGPoint { get }
    var topRight: CGPoint { get }
    var bottomLeft: CGPoint { get }
    var bottomRight: CGPoint { get }
}

extension BoxCorners {
    var center: CGPoint {
        CGPoint(
            x: (topLeft.x + topRight.x + bottomLeft.x + bottomRight.x) / 4,
            y: (topLeft.y + topRight.y + bottomLeft.y + bottomRight.y) / 4
        )
    }
    
    // In radians
    var rotation: CGFloat {
        let dTop = CGVector(dx: topRight.x - topLeft.x, dy: topRight.y - topLeft.y)
        let dBottom = CGVector(dx: bottomRight.x - bottomLeft.x, dy: bottomRight.y - bottomLeft.y)
        let aTop = atan2(dTop.dy, dTop.dx)
        let aBottom = atan2(dBottom.dy, dBottom.dx)
        return (aTop + aBottom) / 2
    }
}

struct PointBox: BoxCorners {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint
}

extension VNRectangleObservation: BoxCorners {}

extension BoxCorners {
    func scaleTo(_ geo: GeometryProxy) -> PointBox {
        let cvtPoint = {(pt: CGPoint) -> CGPoint in
            CGPoint(
                x: pt.x * geo.size.width,
                y: (1 - pt.y) * geo.size.height
            )
        }
        return PointBox(
            topLeft: cvtPoint(self.topLeft),
            topRight: cvtPoint(self.topRight),
            bottomLeft: cvtPoint(self.bottomLeft),
            bottomRight: cvtPoint(self.bottomRight)
        )
    }
}

struct DisplayOptions: OptionSet {
    let rawValue: Int

    static let rects = Self(rawValue: 1 << 0)
    static let characters = Self(rawValue: 1 << 1)
    static let recognizedText = Self(rawValue: 1 << 2)

    static let all: Self = [.rects, .characters, .recognizedText]
}

struct ContentView: View {
    
    @State var img: NSImage? = nil

    @StateObject var vision = VisionAPI()
    
    var body: some View {
        DropableImageFile(img: $img)
            .overlay{
                Group {
                    if let texts = vision.texts, let rects = vision.rects, let recogTexts = vision.recogTexts {
                        RectOverlay(display: .all, texts: texts, rects: rects, recogText: recogTexts)
                    }
                }
            }
            .onChange(of: img) { newValue in
                Task {
                    guard let image = newValue,
                            let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
                    else {
                        vision.texts = nil
                        vision.rects = nil
                        return
                    }
                    await vision.doVisionRequest(image: cg)
                }
            }
            .padding()
    }
}

struct DropableImageFile: View {
    @State var flag = false
    @Binding var img: NSImage?
    
    var body: some View {
        Rectangle()
            .fill(self.flag ? Color.green : Color.gray)
            .overlay(Text("Drop Here"))
            .overlay(Image(nsImage: img ?? NSImage()).resizable())
            .onDrop(of: [UTType.fileURL.identifier, UTType.png.identifier, UTType.jpeg.identifier], isTargeted: $flag, perform: { items in
                
                if let item = items.first {
                    if item.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        item.loadItem(forTypeIdentifier: UTType.image.identifier) { (data, error) in
                            if let data = data as? Data {
                                img = NSImage(data: data)
                            }
                        }
                        return true
                    } else if item.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                        item.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                            if let urlData = urlData as? Data {
                                let u = NSURL.init(absoluteURLWithDataRepresentation: urlData, relativeTo: nil)
                                img = NSImage(byReferencing: u as URL)
                            }
                        }
                        return true
                    }
                }
                    
                return false
            })
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
