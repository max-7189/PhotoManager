import SwiftUI
import Photos

struct ThumbnailStrip: View {
    let items: [MediaItem]
    let currentIndex: Int
    let onThumbnailTap: (Int) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                HStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        thumbnailView(for: item, at: index)
                            .id(index)
                    }
                }
                .onChange(of: currentIndex) { newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }
    
    private func thumbnailView(for item: MediaItem, at index: Int) -> some View {
        Image(uiImage: item.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 60)
            .clipped()
            .overlay(
                Group {
                    if index == currentIndex {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.blue, lineWidth: 2)
                    }
                }
            )
            .overlay(
                Group {
                    if item.markStatus == .delete {
                        Color.red.opacity(0.3)
                    } else if item.markStatus == .keep {
                        Color.green.opacity(0.3)
                    }
                }
            )
            .cornerRadius(4)
            .onTapGesture {
                onThumbnailTap(index)
            }
    }
} 