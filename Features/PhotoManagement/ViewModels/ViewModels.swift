import SwiftUI
import Photos
import AVKit

// MARK: - VideoCardViewModel
class VideoCardViewModel: ObservableObject {
    @Published var currentImage: UIImage?
    @Published var isLoadingFullQuality = false
    @Published var player: AVPlayer?
    @Published var isPlayerReady = false
    
    private var loadingTimer: Timer?
    private let photoManager: PhotoManager
    private let mediaItem: MediaItem
    private var playerStatusObserver: NSKeyValueObservation?
    
    init(photoManager: PhotoManager, mediaItem: MediaItem) {
        print("【VideoCardViewModel】初始化 - ID: \(mediaItem.id)")
        self.photoManager = photoManager
        self.mediaItem = mediaItem
        self.currentImage = mediaItem.thumbnail
        
        if let videoURL = mediaItem.videoURL {
            print("【VideoCardViewModel】创建播放器 - ID: \(mediaItem.id), URL: \(videoURL)")
            let player = AVPlayer(url: videoURL)
            self.player = player
            
            // 观察播放器状态
            self.playerStatusObserver = player.currentItem?.observe(\.status) { [weak self] item, _ in
                DispatchQueue.main.async {
                    self?.isPlayerReady = item.status == .readyToPlay
                    if item.status == .failed {
                        print("【VideoCardViewModel】播放器加载失败 - ID: \(self?.mediaItem.id ?? "")")
                    }
                }
            }
        } else {
            print("【VideoCardViewModel】警告：无法获取视频URL - ID: \(mediaItem.id)")
        }
    }
    
    func handleImageLoading() {
        // 只加载预览图，不加载高质量图片
        photoManager.loadImage(for: mediaItem.asset, quality: .preview) { [weak self] image in
            DispatchQueue.main.async {
                if let image = image {
                    print("【VideoCardViewModel】预览图加载完成 - ID: \(self?.mediaItem.id ?? "")")
                    self?.currentImage = image
                }
            }
        }
    }
    
    func playVideo() {
        print("【VideoCardViewModel】尝试播放视频 - ID: \(mediaItem.id)")
        if let player = player, isPlayerReady {
            print("【VideoCardViewModel】开始播放 - ID: \(mediaItem.id)")
            player.play()
        } else {
            print("【VideoCardViewModel】等待播放器就绪 - ID: \(mediaItem.id)")
        }
    }
    
    func pauseVideo() {
        print("【VideoCardViewModel】暂停视频 - ID: \(mediaItem.id)")
        player?.pause()
    }
    
    func cancelLoading() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        photoManager.cancelImageLoading(for: mediaItem.id)
    }
    
    deinit {
        print("【VideoCardViewModel】释放 - ID: \(mediaItem.id)")
        playerStatusObserver?.invalidate()
        cancelLoading()
        pauseVideo()
    }
}

// MARK: - PhotoCardViewModel
class PhotoCardViewModel: ObservableObject {
    @Published var currentImage: UIImage?
    @Published var isLoadingFullQuality = false
    
    private var loadingTimer: Timer?
    private let photoManager: PhotoManager
    private let mediaItem: MediaItem
    
    init(photoManager: PhotoManager, mediaItem: MediaItem) {
        self.photoManager = photoManager
        self.mediaItem = mediaItem
        self.currentImage = mediaItem.thumbnail
    }
    
    func handleImageLoading() {
        // 如果已经有高质量图片，直接使用
        if let fullQualityImage = mediaItem.fullQualityImage {
            print("【PhotoCardViewModel】使用缓存的高清图 - ID: \(mediaItem.id)")
            self.currentImage = fullQualityImage
            return
        }
        
        // 如果有预览图，先显示预览图
        if let previewImage = mediaItem.previewImage {
            print("【PhotoCardViewModel】使用缓存的预览图 - ID: \(mediaItem.id)")
            self.currentImage = previewImage
        } else {
            // 没有预览图，显示缩略图
            self.currentImage = mediaItem.thumbnail
        }
        
        // 加载预览图
        print("【PhotoCardViewModel】开始加载预览图 - ID: \(mediaItem.id)")
        photoManager.loadImage(for: mediaItem.asset, quality: .preview) { [weak self] image in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let image = image {
                    print("【PhotoCardViewModel】预览图加载完成 - ID: \(self.mediaItem.id)")
                    if self.currentImage === self.mediaItem.thumbnail {
                        self.currentImage = image
                    }
                }
            }
        }
        
        // 立即开始加载高清图
        print("【PhotoCardViewModel】开始加载高清图 - ID: \(mediaItem.id)")
        self.isLoadingFullQuality = true
        photoManager.loadImage(for: mediaItem.asset, quality: .fullQuality) { [weak self] image in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let image = image {
                    print("【PhotoCardViewModel】高清图加载完成 - ID: \(self.mediaItem.id)")
                    self.currentImage = image
                }
                self.isLoadingFullQuality = false
            }
        }
    }
    
    func getCurrentImageQuality() -> String {
        if let currentImage = currentImage {
            if currentImage === mediaItem.fullQualityImage {
                return "高清"
            } else if currentImage === mediaItem.previewImage {
                return "预览"
            } else if currentImage === mediaItem.thumbnail {
                return "缩略图"
            }
        }
        return "未知"
    }
    
    func cancelLoading() {
        print("【PhotoCardViewModel】取消加载 - ID: \(mediaItem.id)")
        loadingTimer?.invalidate()
        loadingTimer = nil
        photoManager.cancelImageLoading(for: mediaItem.id)
    }
    
    deinit {
        cancelLoading()
    }
} 