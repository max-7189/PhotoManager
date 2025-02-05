import SwiftUI
import Photos
import AVKit

// MARK: - Common Types
typealias CardGesture = _EndedGesture<_ChangedGesture<DragGesture>>

// MARK: - VideoCard
struct VideoCard: View {
    let mediaItem: MediaItem
    let offset: CGSize
    let isCurrentVideo: Bool
    @StateObject private var viewModel: VideoCardViewModel
    
    init(mediaItem: MediaItem, offset: CGSize, isCurrentVideo: Bool, photoManager: PhotoManager) {
        self.mediaItem = mediaItem
        self.offset = offset
        self.isCurrentVideo = isCurrentVideo
        _viewModel = StateObject(wrappedValue: VideoCardViewModel(photoManager: photoManager, mediaItem: mediaItem))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let player = viewModel.player, isCurrentVideo, viewModel.isPlayerReady {
                    VideoPlayerContainer(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .onAppear {
                            print("【VideoCard】播放器出现 - ID: \(mediaItem.id)")
                        }
                        .onDisappear {
                            print("【VideoCard】播放器消失 - ID: \(mediaItem.id)")
                            viewModel.pauseVideo()
                        }
                } else if let image = viewModel.currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                                .opacity(0.8)
                        )
                        .onTapGesture {
                            print("【VideoCard】点击预览图 - ID: \(mediaItem.id)")
                            viewModel.playVideo()
                        }
                }
                
                // 加载指示器
                if !viewModel.isPlayerReady && isCurrentVideo {
                    ProgressView()
                        .scaleEffect(0.5)
                        .opacity(0.5)
                }
                
                // 标记状态指示器
                VStack {
                    Spacer()
                    HStack {
                        if mediaItem.markStatus == .delete {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 30))
                        } else if mediaItem.markStatus == .keep {
                            Image(systemName: "heart.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 30))
                        }
                    }
                    .padding(.bottom)
                }
            }
        }
        .offset(offset)
        .id(mediaItem.id)
        .onAppear {
            print("【VideoCard】视图出现 - ID: \(mediaItem.id), 当前视频: \(isCurrentVideo)")
            if isCurrentVideo {
                print("【VideoCard】开始加载视频 - ID: \(mediaItem.id)")
                viewModel.handleImageLoading()
            }
        }
        .onChange(of: isCurrentVideo) { newValue in
            print("【VideoCard】当前状态改变 - ID: \(mediaItem.id), 是否当前: \(newValue)")
            if newValue {
                viewModel.handleImageLoading()
            } else {
                viewModel.cancelLoading()
                viewModel.pauseVideo()
            }
        }
        .onDisappear {
            print("【VideoCard】视图消失 - ID: \(mediaItem.id)")
            viewModel.cancelLoading()
            viewModel.pauseVideo()
        }
    }
}

// MARK: - VideoPlayerContainer
struct VideoPlayerContainer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        
        // 设置视图控制器的视图布局
        controller.view.backgroundColor = .black
        
        // 确保视图控制器被正确添加到视图层级中
        if let window = UIApplication.shared.windows.first {
            window.addSubview(controller.view)
            controller.view.frame = window.bounds
            controller.view.removeFromSuperview()
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}

// MARK: - CustomVideoProgressBar
struct CustomVideoProgressBar: View {
    let progress: Double
    let onSeek: (Double) -> Void
    @State private var isDragging: Bool = false
    @State private var dragProgress: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景条
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 3)
                
                // 进度条
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geometry.size.width * CGFloat(isDragging ? dragProgress : progress), height: 3)
                
                // 拖动手柄
                Circle()
                    .fill(Color.white)
                    .frame(width: 15, height: 15)
                    .offset(x: geometry.size.width * CGFloat(isDragging ? dragProgress : progress) - 7.5)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                dragProgress = min(max(0, Double(value.location.x / geometry.size.width)), 1)
                            }
                            .onEnded { _ in
                                isDragging = false
                                onSeek(dragProgress)
                            }
                    )
            }
        }
        .frame(height: 44)
    }
}

// MARK: - PhotoCard
struct PhotoCard: View {
    let photo: MediaItem
    let offset: CGSize
    let isCurrentPhoto: Bool
    @StateObject private var viewModel: PhotoCardViewModel
    
    init(photo: MediaItem, offset: CGSize, isCurrentPhoto: Bool, photoManager: PhotoManager) {
        self.photo = photo
        self.offset = offset
        self.isCurrentPhoto = isCurrentPhoto
        _viewModel = StateObject(wrappedValue: PhotoCardViewModel(photoManager: photoManager, mediaItem: photo))
    }
    
    var body: some View {
        ZStack {
            if let image = viewModel.currentImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: image) { newImage in
                        print("【PhotoCard】图片更新 - ID: \(photo.id)")
                        let quality = viewModel.getCurrentImageQuality()
                        print("【PhotoCard】当前显示质量 - ID: \(photo.id), 质量: \(quality)")
                    }
            }
            
            if viewModel.isLoadingFullQuality {
                ProgressView()
                    .scaleEffect(0.5)
                    .opacity(0.5)
            }
            
            VStack {
                Spacer()
                HStack {
                    if photo.markStatus == .delete {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 30))
                    } else if photo.markStatus == .keep {
                        Image(systemName: "heart.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 30))
                    }
                }
                .padding(.bottom)
            }
        }
        .offset(offset)
        .id(photo.id) // 确保视图正确重建
        .onAppear {
            print("【PhotoCard】视图出现 - ID: \(photo.id), 当前照片: \(isCurrentPhoto)")
            print("【PhotoCard】初始状态 - 质量: \(viewModel.getCurrentImageQuality())")
            if isCurrentPhoto {
                print("【PhotoCard】开始加载图片 - ID: \(photo.id)")
                viewModel.handleImageLoading()
            }
        }
        .onChange(of: isCurrentPhoto) { newValue in
            print("【PhotoCard】当前状态改变 - ID: \(photo.id), 是否当前: \(newValue)")
            if newValue {
                viewModel.handleImageLoading()
            } else {
                viewModel.cancelLoading()
            }
        }
        .onDisappear {
            print("【PhotoCard】视图消失 - ID: \(photo.id)")
            viewModel.cancelLoading()
        }
    }
} 