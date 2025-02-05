import SwiftUI
import Photos
import CoreData
import AVKit

// 图片质量枚举
enum ImageQuality {
    case thumbnail     // 缩略图条使用，固定小尺寸
    case preview      // 预览图，适中质量，快速加载
    case fullQuality  // 完整质量，用户停留时加载
}

// 媒体项目结构体
struct MediaItem: Identifiable, Equatable {
    let id: String
    let asset: PHAsset
    let thumbnail: UIImage
    let isVideo: Bool
    var videoURL: URL?
    var markStatus: MarkStatus = .none
    var previewImage: UIImage?
    var fullQualityImage: UIImage?
    
    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    enum MarkStatus: Int {
        case none = 0
        case delete
        case keep
        
        init?(rawValue: Int) {
            switch rawValue {
            case 0: self = .none
            case 1: self = .delete
            case 2: self = .keep
            default: return nil
            }
        }
    }
    
    var duration: TimeInterval {
        isVideo ? asset.duration : 0
    }
}

// 照片管理器类,负责处理所有照片相关操作
class PhotoManager: ObservableObject {
    @Published private(set) var mediaItems: [MediaItem] = []
    @Published var errorMessage: String?
    @Published var loadingProgress: Float = 0.0
    
    // 状态管理
    enum ManagerState {
        case loaded
        case error(String)
    }
    var onStateChange: ((ManagerState) -> Void)?
    
    // 核心组件
    private let loadMode: PhotoLoadMode
    private let imageLoadingSystem: ImageLoadingSystem
    private let context = CoreDataManager.shared.context
    private let saveQueue = DispatchQueue(label: "com.app.saveQueue")
    
    // 窗口管理
    private var currentWindowStart = 0
    private var currentIndex = 0
    private var allAssets: [PHAsset] = []
    private var windowSize: Int
    
    // 内存管理
    private var memoryWarningObserver: NSObjectProtocol?
    
    init(loadMode: PhotoLoadMode) {
        self.loadMode = loadMode
        self.windowSize = PhotoLoadingConfig.windowSize
        self.imageLoadingSystem = ImageLoadingSystem(
            maxConcurrentLoads: PhotoLoadingConfig.maxConcurrentLoads,
            cacheSize: PhotoLoadingConfig.cacheSize
        )
        
        // 延迟设置内存警告观察者
        DispatchQueue.main.async { [weak self] in
            self?.setupMemoryWarningObserver()
        }
    }
    
    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        let memoryLevel = ProcessInfo.processInfo.thermalState.rawValue
        windowSize = PhotoLoadingConfig.adjustWindowSize(for: memoryLevel)
        updateWindow(currentIndex: currentIndex)
    }
    
    func requestAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        DispatchQueue.main.async { [weak self] in
            switch status {
            case .authorized, .limited:
                self?.initializeAssets()
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                    DispatchQueue.main.async {
                        if newStatus == .authorized || newStatus == .limited {
                            self?.initializeAssets()
                        } else {
                            self?.onStateChange?(.error("需要相册访问权限才能使用此功能"))
                        }
                    }
                }
            default:
                self?.onStateChange?(.error("无法访问相册"))
            }
        }
    }
    
    private func initializeAssets() {
        allAssets = loadMode.assets
        print("【初始化】完成资产加载，总数：\(allAssets.count)")
        loadInitialBatch()
    }
    
    private func loadInitialBatch() {
        guard !allAssets.isEmpty else {
            print("【错误】没有可加载的资产")
            return
        }
        
        loadingProgress = 0.0
        print("【加载】开始加载所有缩略图，总数: \(allAssets.count)")
        loadAssetsAsync(allAssets) { [weak self] items in
            guard let self = self else {
                print("【错误】PhotoManager 已释放")
                return
            }
            
            // 先加载标记状态
            Task { @MainActor in
                self.mediaItems = items
                print("【加载】媒体项加载完成，数量：\(items.count)")
                
                do {
                    print("【加载】开始加载标记状态")
                    try await self.loadMarkStatusAsync()
                    
                    print("【加载】标记状态加载完成，开始显示界面")
                    self.onStateChange?(.loaded)
                    
                    print("【预加载】开始预加载高质量图片")
                    self.preloadHighQualityImages(around: 0)
                } catch {
                    print("【错误】加载过程出错: \(error)")
                    self.onStateChange?(.error("加载媒体时出错"))
                }
            }
        }
    }
    
    func handleScroll(currentIndex: Int) {
        print("【滚动】当前索引: \(currentIndex)")
        self.currentIndex = currentIndex
        
        // 检查是否需要加载更多
        if currentIndex >= mediaItems.count - PhotoLoadingConfig.preloadThreshold {
            print("【加载】触发加载更多，当前位置：\(currentIndex)")
            loadNextBatch()
        }
        
        // 更新窗口并预加载
        updateWindow(currentIndex: currentIndex)
        print("【预加载】开始为索引 \(currentIndex) 预加载高质量图片")
        preloadHighQualityImages(around: currentIndex)
    }
    
    private func loadNextBatch() {
        let startIndex = mediaItems.count
        let endIndex = min(startIndex + PhotoLoadingConfig.preloadBatchSize, allAssets.count)
        
        guard startIndex < endIndex else { return }
        
        let nextAssets = Array(allAssets[startIndex..<endIndex])
        loadAssetsAsync(nextAssets) { [weak self] newItems in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.mediaItems.append(contentsOf: newItems)
            }
        }
    }
    
    private func updateWindow(currentIndex: Int) {
        // 计算需要保持的范围：当前位置前后50张
        let start = max(0, currentIndex - PhotoLoadingConfig.highQualityWindow)
        let end = min(mediaItems.count, currentIndex + PhotoLoadingConfig.highQualityWindow + 1)
        let keepRange = start..<end
        
        // 释放范围外的内存
        releaseMemoryForItemsOutside(keepRange)
        
        // 更新当前窗口起始位置
        currentWindowStart = keepRange.lowerBound
    }
    
    private func preloadHighQualityImages(around index: Int) {
        // 计算预加载范围：当前位置前后各50张
        let preloadWindow = PhotoLoadingConfig.highQualityWindow / 2  // 将窗口平均分配给前后
        let start = max(0, index - preloadWindow)
        let end = min(index + preloadWindow + 1, mediaItems.count)
        let range = start..<end
        
        print("【预加载】范围：\(range)，当前索引：\(index)")
        
        // 按照到当前位置的距离排序要加载的索引
        let sortedIndices = range.sorted { idx1, idx2 in
            abs(idx1 - index) < abs(idx2 - index)
        }
        
        for i in sortedIndices {
            let item = mediaItems[i]
            if item.fullQualityImage != nil {
                print("【缓存】索引 \(i) 的高质量图片已存在")
                continue
            }
            
            // 如果是视频，跳过高质量图片加载
            if item.isVideo {
                continue
            }
            
            // 计算优先级：距离当前位置越近，优先级越高
            let distance = abs(i - index)
            let priority = PhotoLoadingConfig.getPriority(distance: distance)
            
            print("【加载】开始加载索引 \(i) 的高质量图片，优先级：\(priority)，距离：\(distance)")
            loadImage(for: item.asset, quality: .fullQuality) { [weak self] image in
                guard let self = self,
                      let image = image else {
                    print("【错误】索引 \(i) 的高质量图片加载失败")
                    return
                }
                
                DispatchQueue.main.async {
                    print("【完成】索引 \(i) 的高质量图片加载完成")
                    if let index = self.mediaItems.firstIndex(where: { $0.id == item.id }) {
                        var updatedItem = self.mediaItems[index]
                        updatedItem.fullQualityImage = image
                        self.mediaItems[index] = updatedItem
                    }
                }
            }
        }
    }
    
    private func releaseMemoryForItemsOutside(_ keepRange: Range<Int>) {
        // 遍历所有项目
        for index in 0..<mediaItems.count {
            // 如果在保持范围内，跳过
            guard !keepRange.contains(index) else { continue }
            
            let item = mediaItems[index]
            
            // 如果是视频，不需要释放内存
            if item.isVideo {
                continue
            }
            
            // 取消正在进行的加载
            imageLoadingSystem.cancelLoading(for: "\(item.id)_fullQuality")
            imageLoadingSystem.cancelLoading(for: "\(item.id)_preview")
            
            // 只保留缩略图
            var updatedItem = item
            if updatedItem.fullQualityImage != nil {
                print("【内存】释放索引 \(index) 的高质量图片")
                updatedItem.fullQualityImage = nil
            }
            if updatedItem.previewImage != nil {
                print("【内存】释放索引 \(index) 的预览图")
                updatedItem.previewImage = nil
            }
            
            mediaItems[index] = updatedItem
        }
    }
    
    func loadImage(for asset: PHAsset, quality: ImageQuality, completion: @escaping (UIImage?) -> Void) {
        let priority: LoadingPriority = quality == .thumbnail ? .normal : .high
        imageLoadingSystem.loadImage(for: asset, quality: quality, priority: priority, completion: completion)
    }
    
    func cancelImageLoading(for assetID: String) {
        imageLoadingSystem.cancelLoading(for: "\(assetID)_fullQuality")
        imageLoadingSystem.cancelLoading(for: "\(assetID)_preview")
    }
    
    private func loadAssetsAsync(_ assets: [PHAsset], completion: @escaping ([MediaItem]) -> Void) {
        var items: [MediaItem] = []
        let group = DispatchGroup()
        
        for asset in assets {
            group.enter()
            
            // 加载缩略图
            imageLoadingSystem.loadImage(for: asset, quality: .thumbnail, priority: .normal) { [weak self] thumbnail in
                guard let thumbnail = thumbnail else {
                    group.leave()
                    return
                }
                
                let id = "\(asset.localIdentifier)"
                let isVideo = asset.mediaType == .video
                
                if isVideo {
                    // 如果是视频，加载视频 URL
                    let options = PHVideoRequestOptions()
                    options.version = .original
                    options.deliveryMode = .fastFormat
                    
                    PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                        DispatchQueue.main.async {
                            var item = MediaItem(
                                id: id,
                                asset: asset,
                                thumbnail: thumbnail,
                                isVideo: true
                            )
                            
                            if let urlAsset = avAsset as? AVURLAsset {
                                print("【视频】成功获取视频URL - ID: \(id)")
                                item.videoURL = urlAsset.url
                            } else {
                                print("【视频】无法获取视频URL - ID: \(id)")
                            }
                            
                            items.append(item)
                            group.leave()
                        }
                    }
                } else {
                    // 如果是照片，直接创建 MediaItem
                    let item = MediaItem(
                        id: id,
                        asset: asset,
                        thumbnail: thumbnail,
                        isVideo: false
                    )
                    items.append(item)
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(items)
        }
    }
    
    // MARK: - 标记和删除功能
    
    func markForDeletion(at index: Int) {
        guard index < mediaItems.count else { return }
        var item = mediaItems[index]
        item.markStatus = .delete
        mediaItems[index] = item
        saveMarkStatus(for: item)
    }
    
    func keepCurrentPhoto(at index: Int) {
        guard index < mediaItems.count else { return }
        var item = mediaItems[index]
        item.markStatus = .keep
        mediaItems[index] = item
        saveMarkStatus(for: item)
    }
    
    private func saveMarkStatus(for item: MediaItem) {
        saveQueue.async { [weak self] in
            guard let self = self else {
                print("保存标记状态失败：self 已释放")
                return
            }
            Task {
                do {
                    // 等待 CoreData 存储加载完成
                    try await CoreDataManager.shared.waitForStore()
                    
                    let fetchRequest: NSFetchRequest<MediaItemEntity> = MediaItemEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", item.id)
                    
                    let results = try self.context.fetch(fetchRequest)
                    let entity: MediaItemEntity
                    if let existing = results.first {
                        entity = existing
                    } else {
                        entity = MediaItemEntity(context: self.context)
                        entity.id = item.id
                    }
                    entity.markStatus = Int16(item.markStatus.rawValue)
                    try self.context.save()
                    print("成功保存标记状态：\(item.id)")
                } catch {
                    print("保存标记状态失败: \(error)")
                }
            }
        }
    }
    
    private func loadMarkStatusAsync() async throws {
        // 等待 CoreData 存储加载完成
        try await CoreDataManager.shared.waitForStore()
        
        let fetchRequest: NSFetchRequest<MediaItemEntity> = MediaItemEntity.fetchRequest()
        
        let entities = try await context.perform {
            try self.context.fetch(fetchRequest)
        }
        
        // 直接在 @MainActor 上下文中更新
        var updatedItems = self.mediaItems
        for (index, item) in updatedItems.enumerated() {
            if let entity = entities.first(where: { $0.id == item.id }) {
                var updatedItem = item
                updatedItem.markStatus = MediaItem.MarkStatus(rawValue: Int(entity.markStatus)) ?? .none
                updatedItems[index] = updatedItem
            }
        }
        
        self.mediaItems = updatedItems
        print("标记状态加载完成")
    }
    
    func confirmDelete(completion: @escaping (Bool) -> Void) {
        let itemsToDelete = mediaItems.filter { $0.markStatus == .delete }
        guard !itemsToDelete.isEmpty else {
            completion(true)
            return
        }
        
        let assets = itemsToDelete.map { $0.asset }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    self.mediaItems.removeAll { itemsToDelete.contains($0) }
                }
                completion(success)
            }
        }
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        imageLoadingSystem.cleanup()
    }
}

// 线程安全的数组包装类
class Atomic<T> {
    private let queue = DispatchQueue(label: "com.app.atomic")
    private var _value: T
    
    init(_ value: T) {
        self._value = value
    }
    
    var value: T {
        return queue.sync { _value }
    }
    
    func append(_ element: T.Element) where T: RangeReplaceableCollection {
        queue.sync {
            _value.append(element)
        }
    }
}
