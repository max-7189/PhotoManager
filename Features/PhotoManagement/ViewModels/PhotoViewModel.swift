import SwiftUI
import Photos

class PhotoViewModel: ObservableObject {
    @Published var currentIndex = 0
    @Published var showingDeleteConfirmation = false
    @Published var viewState: ViewState = .loading
    @Published var offset: CGSize = .zero
    @Published var isAnimating = false
    
    private let photoManager: PhotoManager
    private var loadingTimer: Timer?
    
    var imageManager: PhotoManager { photoManager }
    
    enum ViewState {
        case loading
        case loaded
        case error(String)
    }
    
    var mediaItems: [MediaItem] { photoManager.mediaItems }
    var loadingProgress: Float { photoManager.loadingProgress }
    var pendingDeletionsCount: Int { mediaItems.filter { $0.markStatus == .delete }.count }
    
    var currentItems: [MediaItem] {
        guard !mediaItems.isEmpty else { return [] }
        let start = max(0, currentIndex - 1)
        let end = min(mediaItems.count, currentIndex + 2)
        return Array(mediaItems[start..<end])
    }
    
    init(loadMode: PhotoLoadMode) {
        self.photoManager = PhotoManager(loadMode: loadMode)
        setupPhotoManager()
    }
    
    private func setupPhotoManager() {
        photoManager.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .loaded:
                    self?.viewState = .loaded
                case .error(let message):
                    self?.viewState = .error(message)
                }
            }
        }
        
        photoManager.requestAuthorization()
    }
    
    func handleScroll(currentIndex: Int) {
        self.currentIndex = currentIndex
        photoManager.handleScroll(currentIndex: currentIndex)
    }
    
    func handleDelete() {
        guard currentIndex < mediaItems.count else { return }
        photoManager.markForDeletion(at: currentIndex)
        moveToNext()
    }
    
    func handleKeep() {
        guard currentIndex < mediaItems.count else { return }
        photoManager.keepCurrentPhoto(at: currentIndex)
        moveToNext()
    }
    
    private func moveToNext() {
        if currentIndex < mediaItems.count - 1 {
            currentIndex += 1
        }
    }
    
    func handleThumbnailTap(_ index: Int) {
        guard index < mediaItems.count else { return }
        currentIndex = index
    }
    
    func showDeleteConfirmation() {
        showingDeleteConfirmation = true
    }
    
    func confirmDelete() {
        photoManager.confirmDelete { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    print("批量删除成功")
                    self?.showingDeleteConfirmation = false
                } else {
                    print("批量删除失败")
                }
            }
        }
    }
    
    func loadImage(for asset: PHAsset, quality: ImageQuality, completion: @escaping (UIImage?) -> Void) {
        photoManager.loadImage(for: asset, quality: quality, completion: completion)
    }
    
    func cancelImageLoading(for assetID: String) {
        photoManager.cancelImageLoading(for: assetID)
    }
    
    deinit {
        loadingTimer?.invalidate()
    }
} 