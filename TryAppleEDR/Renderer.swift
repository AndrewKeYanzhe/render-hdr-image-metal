import CoreImage
import Metal
import MetalKit
import SwiftUI

final class Renderer: NSObject, MTKViewDelegate, ObservableObject {
    public let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let context: CIContext

    let imageProvider: (_ scaleFactor: CGFloat, _ currentEDRHeadroom: CGFloat, _ potentialEDRHeadroom: CGFloat) -> CIImage

    init(imageProvider: @escaping (_ scaleFactor: CGFloat, _ currentEDRHeadroom: CGFloat, _ potentialEDRHeadroom: CGFloat) -> CIImage) {
        self.imageProvider = imageProvider
        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = device?.makeCommandQueue()
        self.context = CIContext(mtlDevice: device!)
        super.init()
    }

    func draw(in view: MTKView) {
        let screen = view.window?.screen
        var currentEDRHeadroom = 1.0
        var potentialEDRHeadroom = 1.0
        #if os(macOS)
            currentEDRHeadroom = screen!.maximumExtendedDynamicRangeColorComponentValue
            potentialEDRHeadroom = screen!.maximumPotentialExtendedDynamicRangeColorComponentValue
            let contentScale = view.convertToBacking(CGSize(width: 1.0, height: 1.0)).width
        #else
            currentEDRHeadroom = screen!.currentEDRHeadroom
            potentialEDRHeadroom = screen!.potentialEDRHeadroom
            let contentScale = view.contentScaleFactor
        #endif

        // Create a CIImage from the image provider.
        let image = imageProvider(contentScale, currentEDRHeadroom, potentialEDRHeadroom)

        // Render the CIImage to the view's drawable.
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue?.makeCommandBuffer() else { return }

        // Modify the render pass descriptor's color attachment to clear with black.
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        let context = CIContext(mtlDevice: view.device!)

        let dSize = view.drawableSize
        let backBounds = CGRect(x: 0, y: 0, width: dSize.width, height: dSize.height)
        // Render the image to the MTLTexture
        context.render(image, to: drawable.texture, commandBuffer: commandBuffer, bounds: backBounds, colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020)!)

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
