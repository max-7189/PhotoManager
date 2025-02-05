import SwiftUI
import Photos

class PhotoViewModel: ObservableObject {
    @Published var currentIndex = 0
    @Published var showingDeleteConfirmation = false
    
    private let photoManager: PhotoManager
    
    var mediaItems: [MediaItem] { photoManager.mediaItems }
    var isInitialLoading: Bool { photoManager.isInitialLoading }
    var loadingProgress: Float { photoManager.loadingProgress }
    var pendingDeletionsCount: Int { mediaItems.filter { $0.markStatus == .delete }.count }
    
    init(loadMode: PhotoLoadMode) {
        self.photoManager = PhotoManager(loadMode: loadMode)
        self.photoManager.requestAuthorization()
    }
    
    func handleScroll(currentIndex: Int) {
        self.currentIndex = currentIndex
        photoManager.handleScroll(currentIndex: currentIndex)
    }
    
    func markForDeletion(at index: Int) {
        guard index < mediaItems.count else { return }
        var item = mediaItems[index]
        
        let oldStatus = item.markStatus
        if item.markStatus == .delete {
            item.markStatus = .none
        } else {
            item.markStatus = .delete
        }
        print("标记删除状态改变: ID=\(item.id), 旧状态=\(oldStatus.rawValue), 新状态=\(item.markStatus.rawValue)")
        
        saveMarkForItem(item)
    }
    
    func keepCurrentPhoto(at index: Int) {
        guard index < mediaItems.count else { return }
        var item = mediaItems[index]
        
        let oldStatus = item.markStatus
        if item.markStatus == .keep {
            item.markStatus = .none
        } else {
            item.markStatus = .keep
        }
        print("标记保留状态改变: ID=\(item.id), 旧状态=\(oldStatus.rawValue), 新状态=\(item.markStatus.rawValue)")
        
        saveMarkForItem(item)
    }
    
    private func saveMarkForItem(_ item: MediaItem) {
        let context = CoreDataManager.shared.context
        context.performAndWait {
            let fetchRequest: NSFetchRequest<MediaItemEntity> = MediaItemEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", item.id)
            
            do {
                let results = try context.fetch(fetchRequest)
                let entity = results.first ?? MediaItemEntity(context: context)
                entity.id = item.id
                entity.markStatus = Int16(item.markStatus.rawValue)
                
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                print("保存标记失败: \(error)")
            }
        }
    }
    
    func showDeleteConfirmation() {
        showingDeleteConfirmation = true
    }
    
    func confirmDelete() {
        let itemsToDelete = mediaItems.filter { $0.markStatus == .delete }
        guard !itemsToDelete.isEmpty else { return }
        
        PHPhotoLibrary.shared().performChanges {
            let assetsToDelete = itemsToDelete.map { $0.asset }
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
        } completionHandler: { success, error in
            if success {
                DispatchQueue.main.async {
                    // 从Core Data中删除对应的记录
                    let context = CoreDataManager.shared.context
                    context.performAndWait {
                        let fetchRequest: NSFetchRequest<MediaItemEntity> = MediaItemEntity.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "id IN %@", itemsToDelete.map { $0.id })
                        
                        do {
                            let entities = try context.fetch(fetchRequest)
                            entities.forEach { context.delete($0) }
                            try context.save()
                        } catch {
                            print("删除Core Data记录失败: \(error)")
                        }
                    }
                }
            }
        }
    }
} 