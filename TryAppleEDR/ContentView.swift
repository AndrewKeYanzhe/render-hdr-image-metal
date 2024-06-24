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
            CircleView()

            #if os(macOS)
            Text("Current Screen: \(NSScreen.main!.localizedName)")
            #endif

            VStack {
                GeometryReader { geometry in
                    let renderer = Renderer(imageProvider: { (scaleFactor: CGFloat, _: CGFloat, potentialEDRHeadroom: CGFloat) -> CIImage in
                        let windowSize = geometry.size

                        // Define the size of the square
                        let pixelSize = CGSize(width: windowSize.width * scaleFactor, height: windowSize.height * scaleFactor)
                        // Create a rounded rectangle
                        let roundedRectangleGenerator = CIFilter.roundedRectangleGenerator()
                        roundedRectangleGenerator.color = CIColor(red: headroom, green: headroom, blue: headroom, colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!)!
                        roundedRectangleGenerator.extent = CGRect(origin: .zero, size: pixelSize)
                        roundedRectangleGenerator.radius = 0
                        return roundedRectangleGenerator.outputImage!
                    })

                    MetalView(renderer: renderer)
                }
            }
            .frame(height: 30)

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
