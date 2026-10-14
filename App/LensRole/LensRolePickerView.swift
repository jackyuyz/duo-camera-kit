import SwiftUI
import LinkKit

struct LensRolePickerView: View {
    @Environment(\.foldStateProvider) private var foldStateProvider
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Choose Your Role")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Two iPhones work together: one controls, one captures")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                NavigationLink {
                    LensControlView()
                } label: {
                    RoleCard(
                        role: .control,
                        isRecommended: foldStateProvider.state.hasHinge
                    )
                }
                
                NavigationLink {
                    LensDeviceView()
                } label: {
                    RoleCard(
                        role: .lens,
                        isRecommended: !foldStateProvider.state.hasHinge
                    )
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 32)
        .background(Color.black)
        .navigationTitle("Lens Mode")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RoleCard: View {
    let role: DeviceRole
    let isRecommended: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: role == .control ? "rectangle.portrait.on.rectangle.portrait" : "camera.fill")
                    .font(.title2)
                    .foregroundStyle(role == .control ? .blue : .orange)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text(role == .control ? "Control" : "Lens")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        if isRecommended {
                            Text("Recommended")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(role == .control ? "Monitor and control the other iPhone" : "This iPhone becomes the camera")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        LensRolePickerView()
    }
}
