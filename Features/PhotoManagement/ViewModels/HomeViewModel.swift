import SwiftUI
import Photos

class HomeViewModel: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published var totalPhotos: Int = 0
    private let photoManager: PhotoManager
    
    override init() {
        // 创建一个用于主页的PhotoManager实例，使用.all模式
        self.photoManager = PhotoManager(loadMode: .all)
        
        // 必须先调用super.init()
        super.init()
        
        // 监听照片库变化
        PHPhotoLibrary.shared().register(self)
        updatePhotoCount()
    }
    
    private func updatePhotoCount() {
        totalPhotos = photoManager.mediaItems.count
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    // MARK: - PHPhotoLibraryChangeObserver
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {
            self.updatePhotoCount()
        }
    }
} 