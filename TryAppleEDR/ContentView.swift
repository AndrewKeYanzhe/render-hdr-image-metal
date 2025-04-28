import Combine
import CoreImage.CIFilterBuiltins
import SwiftUI

struct ScreenInfo: Hashable {
    let localizedName: String
    let currentEDRHeadroom: CGFloat
    let potentialEDRHeadroom: CGFloat
}

struct ContentView: View {
    #if os(macOS)
    @StateObject private var screenObserver = ScreenObserver()
    #endif

    @State private var headroom = 1.0

    var body: some View {
        VStack(spacing: 0) {
//            CircleView()

            #if os(macOS)
            Text("Current Screen: \(NSScreen.main!.localizedName)")
            #endif

            VStack {
                GeometryReader { geometry in
                    let renderer = Renderer(imageProvider: { (scaleFactor: CGFloat, _: CGFloat, potentialEDRHeadroom: CGFloat) -> CIImage in
                        // Load the HDR image from the app bundle
                        guard let url = Bundle.main.url(forResource: "your_hdr_image", withExtension: "avif"),
                              let sourceImage = CIImage(contentsOf: url) else {
                            fatalError("HDR image not found.")
                        }
                        
                        // Define the source PQ BT.2020 color space and destination Linear BT.2020
                        let pqBT2020 = CGColorSpace(name: CGColorSpace.itur_2100_PQ)!
                        let linearBT2020 = CGColorSpace(name: CGColorSpace.linearITUR_2020)!
                        
                        // Apply real PQ to Linear decoding
//                        let decodedImage = sourceImage.applyingFilter("CIColorSpaceConversion", parameters: [
//                            "inputSourceSpace": pqBT2020,
//                            "inputDestinationSpace": linearBT2020
//                        ])
                        
                        
                        
//                        return decodedImage
                        
//                        working
//                        return sourceImage
                        
                        // let imageToScale = sourceImage
                                
                        // // Apply scaling
                        // let scale = 0.25 // For example, scale down to 50%
                        // let scaledImage = imageToScale.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                        
                        return sourceImage
                    })

                    MetalView(renderer: renderer)
                }
                .frame(height: 500) // You might want bigger than 30 for showing an HDR image

            }
//            .frame(height: 1000)

            Slider(
                value: $headroom,
                in: 0 ... getMainScreenPotentialEDRHeadroom()
            )
            Text("\(headroom)")
                .foregroundColor(.blue)

            #if os(macOS)
            ScreenView(screenObserver: screenObserver)
            #else
            VStack(alignment: .leading) {
                Text("currentEDRHeadroom: \(UIScreen.main.currentEDRHeadroom)")
                Text("potentialEDRHeadroom: \(UIScreen.main.potentialEDRHeadroom)")
            }
            #endif
        }
    }
}

#if os(macOS)
struct ScreenView: View {
    @ObservedObject var screenObserver: ScreenObserver

    var body: some View {
        List {
            ForEach(screenObserver.currentScreens, id: \.localizedName) { screen in // Specify a unique id
                VStack(alignment: .leading) {
                    Text("Name: \(screen.localizedName)")
                    Text("currentEDRHeadroom: \(String(format: "%.3f", screen.currentEDRHeadroom))")
                    Text("potentialEDRHeadroom: \(String(format: "%.3f", screen.potentialEDRHeadroom))")
                }
            }
        }
    }
}

class ScreenObserver: ObservableObject {
    @Published var currentScreens: [ScreenInfo] = []

    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screenDidChange(notification:)),
                                               name: NSWindow.didChangeScreenNotification,
                                               object: nil)
        updateScreens()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func screenDidChange(notification: Notification) {
        updateScreens()
    }

    private func updateScreens() {
        let newScreens = NSScreen.screens.map { ScreenInfo(
            localizedName: $0.localizedName,
            currentEDRHeadroom: $0.maximumExtendedDynamicRangeColorComponentValue,
            potentialEDRHeadroom: $0.maximumPotentialExtendedDynamicRangeColorComponentValue
        ) }
        if newScreens != currentScreens {
            currentScreens = newScreens
        }
    }
}
#endif

#if os(macOS)
func getMainScreenPotentialEDRHeadroom() -> CGFloat {
    return NSScreen.main!.maximumPotentialExtendedDynamicRangeColorComponentValue
}
#else
func getMainScreenPotentialEDRHeadroom() -> CGFloat {
    return UIScreen.main.potentialEDRHeadroom
}
#endif

#Preview {
    ContentView()
}
