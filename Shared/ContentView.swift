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

extension CGRect {
    var square: CGRect {
        let size = max(width, height)
        return CGRect(
            origin: CGPoint(x: midX - size / 2, y: midY - size / 2),
            size: CGSize(width: size, height: size)
        )
    }
}

struct ContentView: View {
    
    @State var img: CGImage? = nil

    @StateObject var vision = VisionAPI()
    
    let padding: CGFloat = 2
    
    func charRects(image: CGImage) -> [CGImage] {
        if let texts = vision.texts {
            return texts.flatMap { obs -> [CGImage] in
                let boxes = obs.characterBoxes ?? []
                // Char box is always axis-aligned
                let (w,h) = (CGFloat(image.width), CGFloat(image.height))
                let t = CGAffineTransform(translationX: 0, y: h).scaledBy(x: w, y: -h)
                
                return boxes
                    .map{$0.boundingBox.applying(t).insetBy(dx: -padding, dy: -padding).square }
                    .compactMap{ image.cropping(to: $0) }
            }
        } else {
            return []
        }
    }
    
    var body: some View {
        if let img {
            AllGlyphsGrid(images: charRects(image: img))
        }
        DropableImageFile(img: $img)
            {
                Group {
                    if let texts = vision.texts,
                       let rects = vision.rects,
                       let recogTexts = vision.recogTexts {
                        RectOverlay(display: .all, texts: texts, rects: rects, recogText: recogTexts)
                    }
                }
            }
            .onChange(of: img) { newValue in
                Task {
                    guard let image = newValue
                    else {
                        vision.texts = nil
                        vision.rects = nil
                        return
                    }
                    await vision.doVisionRequest(image: image)
                }
            }
            .padding()
    }
}

import ImageIO
extension CGImage {
    
    static func from(data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(src, CGImageSourceGetPrimaryImageIndex(src), nil)
    }

    static func from(url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(src, CGImageSourceGetPrimaryImageIndex(src), nil)
    }

    
}

struct AllGlyphsGrid: View {
    
    let images: [CGImage]
    
    var body: some View {
        LazyVGrid(columns: .init(repeating: .init(.adaptive(minimum: 10)), count: 10)) {
            // We don't need them to animate, index is identifior
            ForEach(images.indexed(), id: \.index) { (index, image) in
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}

struct DropableImageFile<Overlay: View>: View {
    @State var flag = false
    @Binding var img: CGImage?
    
    @ViewBuilder var overlay: Overlay
    
    var supportedTypes: [UTType] {
        [UTType.fileURL, UTType.png, UTType.jpeg]
    }
    
    @discardableResult
    func acceptImage(fromProvider item: NSItemProvider) -> Bool {
        if item.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            item.loadItem(forTypeIdentifier: UTType.image.identifier) { (data, error) in
                if let data = data as? Data {
                    img = CGImage.from(data: data)
                }
            }
            return true
        } else if item.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            item.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                if let urlData = urlData as? Data {
                    let u = NSURL.init(absoluteURLWithDataRepresentation: urlData, relativeTo: nil)
                    img = CGImage.from(url: u as URL)
                }
            }
            return true
        }
        return false
    }
    
    var body: some View {
        Rectangle()
            .fill(self.flag ? Color.green : Color.gray)
            .overlay(Text("Drop Here"))
            .overlay(alignment: .center){
                if let img = img {
                    Image(decorative: img, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay(overlay)
                }
            }
            .onPasteCommand(of: supportedTypes) { providers in
                for provider in providers {
                    acceptImage(fromProvider: provider)
                }
            }
            .onDrop(of: supportedTypes.map(\.identifier), isTargeted: $flag, perform: { items in
                if let item = items.first {
                    return acceptImage(fromProvider: item)
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
