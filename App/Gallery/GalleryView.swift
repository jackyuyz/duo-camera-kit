import SwiftUI
import LinkKit

struct GalleryView: View {
    @State private var captures: [CaptureItem] = []
    @State private var selectedCapture: CaptureItem?
    
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 2)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if captures.isEmpty {
                    emptyState
                } else {
                    captureGrid
                }
            }
            .background(Color.black)
            .navigationTitle("Gallery")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Photos", action: {})
                        Button("Videos", action: {})
                        Button("All", action: {})
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(item: $selectedCapture) { capture in
                CaptureDetailView(capture: capture)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Captures Yet")
                .font(.headline)
            
            Text("Photos and videos you capture will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var captureGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(captures) { capture in
                    CaptureGridItem(capture: capture)
                        .onTapGesture {
                            selectedCapture = capture
                        }
                }
            }
        }
    }
}

struct CaptureGridItem: View {
    let capture: CaptureItem
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(1, contentMode: .fill)
            
            Image(systemName: capture.kind == .video ? "video.fill" : "photo.fill")
                .foregroundStyle(.white.opacity(0.5))
            
            if let duration = capture.durationFormatted {
                Text(duration)
                    .font(.caption2)
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
            
            if !capture.transferred && capture.source == .lens {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.orange)
                            .padding(4)
                    }
                    Spacer()
                }
            }
        }
        .clipped()
    }
}

struct CaptureDetailView: View {
    let capture: CaptureItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    Color.black
                    
                    Image(systemName: capture.kind == .video ? "video.fill" : "photo.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(capture.fileName)
                            .font(.headline)
                        Spacer()
                        Text(capture.fileSizeFormatted)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text(capture.createdAt.formatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if capture.source == .lens {
                            Label("Remote", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button {
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        
                        Spacer()
                        
                        Button {
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    GalleryView()
}
