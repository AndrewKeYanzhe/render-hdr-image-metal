import CoreImage
import Metal
import MetalKit
import SwiftUI
import AVFoundation

final class Renderer: NSObject, MTKViewDelegate, ObservableObject {
    public let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let context: CIContext

    private var cachedImage: CIImage?

    let imageProvider: (_ scaleFactor: CGFloat, _ currentEDRHeadroom: CGFloat, _ potentialEDRHeadroom: CGFloat) -> CIImage

    init(imageProvider: @escaping (_ scaleFactor: CGFloat, _ currentEDRHeadroom: CGFloat, _ potentialEDRHeadroom: CGFloat) -> CIImage) {
        self.imageProvider = imageProvider
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
        self.context = CIContext(mtlDevice: device!)
        super.init()

        // Cache image once at init
        cacheImage()
    }

    private func cacheImage() {
        // Create a basic fake scale and EDR values — because at init we may not know real ones
        let dummyScale: CGFloat = 1.0
        let dummyCurrentEDR: CGFloat = 1.0
        let dummyPotentialEDR: CGFloat = 1.0
        cachedImage = imageProvider(dummyScale, dummyCurrentEDR, dummyPotentialEDR)
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let image = cachedImage else {
            return
        }

        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        let dSize = view.drawableSize
        let drawableRect = CGRect(x: 0, y: 0, width: dSize.width, height: dSize.height)

        // Calculate how the image should fit into the drawable
        let fittedRect = AVMakeRect(aspectRatio: image.extent.size, insideRect: drawableRect)

        // Render the original CIImage into the fitted rectangle
        context.render(
            image,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: fittedRect,
            colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020)!
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }


    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No need to re-cache!
    }
}
