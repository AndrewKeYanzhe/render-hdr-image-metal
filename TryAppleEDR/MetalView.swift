import MetalKit
import SwiftUI

struct MetalView: ViewRepresentable {
    func updateView(_ view: MTKView, context: Context) {}
    
    @StateObject var renderer: Renderer
    
    func makeView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        
        view.delegate = renderer
        
        // Suggest to Core Animation, through MetalKit, how often to redraw the view.
        view.preferredFramesPerSecond = 10
        
        // Allow Core Image to render to the view using Metal's compute pipeline.
        view.framebufferOnly = false
        
        if let layer = view.layer as? CAMetalLayer {
            // Enable EDR with a color space that supports values greater than SDR.
            layer.wantsExtendedDynamicRangeContent = true
            layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
            layer.pixelFormat = MTLPixelFormat.rgba16Float
            // Ensure the render view supports pixel values in EDR.
            view.colorPixelFormat = MTLPixelFormat.rgba16Float
        }

        return view
    }
}
