import SwiftUI

struct CircleView: View {
    var body: some View {
        VStack {
            GeometryReader { geometry in
                let renderer = Renderer(imageProvider: { (scaleFactor: CGFloat, currentEDRHeadroom: CGFloat, potentialEDRHeadroom: CGFloat) -> CIImage in

                    var image: CIImage
                    let windowSize = geometry.size
                    let pixelSize = CGSize(width: windowSize.width * scaleFactor, height: windowSize.height * scaleFactor)

                    // Create a white circle
                    let firstCircleFilter = CIFilter.radialGradient()
                    firstCircleFilter.color0 = CIColor(red: 1.0, green: 1.0, blue: 1.0)
                    firstCircleFilter.color1 = CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0)
                    // Set the center of the circle
                    firstCircleFilter.center = CGPoint(x: (pixelSize.width / 2) - (75 * scaleFactor), y: pixelSize.height / 2)
                    firstCircleFilter.radius0 = Float(50 * scaleFactor) // Inner radius of the circle
                    firstCircleFilter.radius1 = Float(50 * scaleFactor) // Outer radius of the circle
                    let firstCircleImage = firstCircleFilter.outputImage?.cropped(to: CGRect(origin: .zero, size: pixelSize))

                    // Overlay the white circle on a black background
                    let firstCompositeFilter = CIFilter.sourceOverCompositing()
                    firstCompositeFilter.inputImage = firstCircleImage
                    firstCompositeFilter.backgroundImage = CIImage.black
                    let firstCompositeImage = firstCompositeFilter.outputImage ?? CIImage()

                    // Create a bright white circle currentEDRHeadroom
                    let brightCircleFilter = CIFilter.radialGradient()
                    brightCircleFilter.color0 = CIColor(red: currentEDRHeadroom, green: currentEDRHeadroom, blue: currentEDRHeadroom,
                                                        colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!)!
                    brightCircleFilter.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
                    // Use the center of the window as the center of the circle
                    brightCircleFilter.center = CGPoint(x: pixelSize.width / 2, y: pixelSize.height / 2)
                    brightCircleFilter.radius0 = Float(50 * scaleFactor) // Inner radius of the circle
                    brightCircleFilter.radius1 = Float(50 * scaleFactor) // Outer radius of the circle
                    let brightCircleImage = brightCircleFilter.outputImage?.cropped(to: CGRect(origin: .zero, size: pixelSize))

                    // Overlay the bright white circle on the image with the white circle
                    let finalCompositeFilter = CIFilter.sourceOverCompositing()
                    finalCompositeFilter.inputImage = brightCircleImage
                    finalCompositeFilter.backgroundImage = firstCompositeImage
                    image = finalCompositeFilter.outputImage ?? CIImage()

                    // Create a bright white circle potentialEDRHeadroom
                    let brightCircleFilterReferenceDisplay = CIFilter.radialGradient()
                    brightCircleFilterReferenceDisplay.color0 = CIColor(red: potentialEDRHeadroom, green: potentialEDRHeadroom, blue: potentialEDRHeadroom,
                                                                        colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!)!
                    brightCircleFilterReferenceDisplay.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
                    // Set the center of the circle
                    brightCircleFilterReferenceDisplay.center = CGPoint(x: (pixelSize.width / 2) + (75 * scaleFactor), y: pixelSize.height / 2)
                    brightCircleFilterReferenceDisplay.radius0 = Float(50 * scaleFactor) // Inner radius of the circle
                    brightCircleFilterReferenceDisplay.radius1 = Float(50 * scaleFactor) // Outer radius of the circle
                    let brightCircleImageReferenceDisplay = brightCircleFilterReferenceDisplay.outputImage?.cropped(to: CGRect(origin: .zero, size: pixelSize))

                    // Overlay the bright white circle on the image with the white circle
                    let newFinalCompositeFilter = CIFilter.sourceOverCompositing()
                    newFinalCompositeFilter.inputImage = brightCircleImageReferenceDisplay
                    newFinalCompositeFilter.backgroundImage = image
                    image = newFinalCompositeFilter.outputImage ?? CIImage()

                    return image.cropped(to: CGRect(origin: .zero, size: pixelSize))
                })

                MetalView(renderer: renderer)
            }
        }
        .frame(height: 150)
    }
}
