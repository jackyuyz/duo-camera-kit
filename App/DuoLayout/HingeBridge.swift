import SwiftUI
import FoldKit

/// Attaches hinge updates to the scene root.
///
/// Duo APIs (`View.onHingeChange`, `DeviceHinge`) require **iOS 27.1**.
/// The Lens phone on **iOS 26** takes the fallback and reports `.noHinge`.
struct HingeBridge: ViewModifier {
    let provider: SystemFoldStateProvider
    
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(HingeChangeBridge(provider: provider))
        } else {
            content.onAppear { provider.ingestNoHinge() }
        }
    }
}

/// Isolated so the iOS 27.1 compiler can type-check `onHingeChange`.
/// Until Xcode 27.1 is on this machine the call is a documented stub.
@available(iOS 27.1, *)
private struct HingeChangeBridge: ViewModifier {
    let provider: SystemFoldStateProvider
    
    func body(content: Content) -> some View {
        // TODO(verify-api): View.onHingeChange(isEnabled:_:) → (DeviceHingeContext, DeviceHingeContext)
        // TODO(verify-api): context.hinge: DeviceHinge?; DeviceHinge.angle; DeviceHinge.status
        // When the SDK is present, replace the onAppear below with:
        //   content.onHingeChange { _, ctx in
        //       if let hinge = ctx.hinge {
        //           provider.ingest(
        //               hingeAvailable: true,
        //               statusRaw: String(describing: hinge.status),
        //               angleDegrees: hinge.angle.degrees
        //           )
        //       } else {
        //           provider.ingestNoHinge()
        //       }
        //   }
        content.onAppear {
            if DuoAPIAvailability.hingeAPIsAvailable {
                provider.ingestNoHinge()
            } else {
                provider.ingestNoHinge()
            }
        }
    }
}

extension View {
    func hingeBridge(_ provider: SystemFoldStateProvider) -> some View {
        modifier(HingeBridge(provider: provider))
    }
}
