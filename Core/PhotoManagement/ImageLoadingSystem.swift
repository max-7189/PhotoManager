import Foundation
import Photos
import UIKit

// 加载任务的优先级
enum LoadingPriority: Int, Comparable {
    case immediate = 0  // 当前显示的图片
    case high = 1      // 即将显示的图片
    case normal = 2    // 预加载的图片
    case low = 3       // 可选加载的图片
    
    static func < (lhs: LoadingPriority, rhs: LoadingPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// 加载任务
struct LoadingTask: Identifiable, Comparable, Equatable {
    let id: String
    let asset: PHAsset
    let quality: ImageQuality
    let priority: LoadingPriority
    let timestamp: Date
    let completion: (UIImage?) -> Void
    
    static func == (lhs: LoadingTask, rhs: LoadingTask) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func < (lhs: LoadingTask, rhs: LoadingTask) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }
        return lhs.timestamp < rhs.timestamp
    }
}

// 图片缓存系统
class ImageCache {
    private let cache = NSCache<NSString, UIImage>()
    private var keys: [String] = []
    private let maxSize: Int
    
    init(maxSize: Int) {
        self.maxSize = maxSize
        cache.countLimit = maxSize
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
        if !keys.contains(key) {
            keys.append(key)
            if keys.count > maxSize {
                if let oldKey = keys.first {
                    remove(oldKey)
                }
            }
        }
    }
    
    func get(_ key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func remove(_ key: String) {
        cache.removeObject(forKey: key as NSString)
        keys.removeAll { $0 == key }
    }
    
    func clear() {
        cache.removeAllObjects()
        keys.removeAll()
    }
}

// 图片加载系统
class ImageLoadingSystem {
    private let imageManager = PHImageManager.default()
    private var loadingQueue: [LoadingTask] = []
    private let operationQueue: OperationQueue
    private let cache: ImageCache
    private var activeRequests: [String: PHImageRequestID] = [:]
    private let serialQueue = DispatchQueue(label: "com.app.imageLoading.serial")
    
    init(maxConcurrentLoads: Int, cacheSize: Int) {
        self.operationQueue = OperationQueue()
        self.operationQueue.maxConcurrentOperationCount = maxConcurrentLoads
        self.cache = ImageCache(maxSize: cacheSize)
    }
    
    // 添加加载任务
    func loadImage(for asset: PHAsset, quality: ImageQuality, priority: LoadingPriority, completion: @escaping (UIImage?) -> Void) {
        let taskId = "\(asset.localIdentifier)_\(quality)"
        
        // 检查缓存
        if let cachedImage = cache.get(taskId) {
            print("【缓存】命中缓存：\(taskId)")
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
        
        // 检查是否已经在队列中
        serialQueue.sync {
            if loadingQueue.contains(where: { $0.id == taskId }) {
                print("【队列】任务已在队列中：\(taskId)")
                return
            }
            
            if activeRequests[taskId] != nil {
                print("【加载】任务正在进行中：\(taskId)")
                return
            }
            
            print("【队列】添加新任务：\(taskId)，优先级：\(priority)")
            // 创建新任务
            let task = LoadingTask(
                id: taskId,
                asset: asset,
                quality: quality,
                priority: priority,
                timestamp: Date(),
                completion: completion
            )
            
            // 添加到队列并排序
            loadingQueue.append(task)
            loadingQueue.sort()
            
            // 处理队列
            processQueue()
        }
    }
    
    // 处理加载队列
    private func processQueue() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("【队列】当前活跃请求数：\(self.activeRequests.count)，队列长度：\(self.loadingQueue.count)")
            
            // 检查是否可以开始新的加载
            while self.activeRequests.count < self.operationQueue.maxConcurrentOperationCount,
                  !self.loadingQueue.isEmpty {
                // 获取最高优先级的任务
                let task = self.loadingQueue.removeFirst()
                print("【队列】开始处理任务：\(task.id)，优先级：\(task.priority)")
                
                // 如果已经在加载，跳过
                guard self.activeRequests[task.id] == nil else {
                    print("【队列】跳过已在进行的任务：\(task.id)")
                    continue
                }
                
                // 开始加载
                self.startLoading(task)
            }
        }
    }
    
    // 开始加载图片
    private func startLoading(_ task: LoadingTask) {
        print("【加载】开始加载图片：\(task.id)")
        let options = PHImageRequestOptions()
        
        // 根据图片质量和优先级设置加载选项
        switch task.quality {
        case .thumbnail:
            options.deliveryMode = .fastFormat
        case .preview:
            options.deliveryMode = task.priority == .immediate ? .highQualityFormat : .opportunistic
        case .fullQuality:
            options.deliveryMode = .highQualityFormat
        }
        
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.version = .current
        
        let targetSize = sizeForQuality(task.quality)
        let completion = task.completion
        let taskId = task.id
        
        // 使用标记避免重复回调
        var hasCompleted = false
        
        let requestId = imageManager.requestImage(
            for: task.asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, info in
            guard !hasCompleted,
                  let self = self,
                  let info = info,
                  info[PHImageCancelledKey] as? Bool != true,
                  info[PHImageErrorKey] == nil
            else {
                if info?[PHImageCancelledKey] as? Bool == true {
                    print("【取消】图片加载已取消：\(taskId)")
                } else if let error = info?[PHImageErrorKey] {
                    print("【错误】图片加载失败：\(taskId)，错误：\(error)")
                }
                return
            }
            
            hasCompleted = true
            
            if let image = image {
                print("【完成】图片加载成功：\(taskId)")
                self.cache.set(image, forKey: taskId)
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                print("【错误】图片加载返回空：\(taskId)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
            
            // 完成后处理下一个任务
            self.serialQueue.async {
                self.activeRequests[taskId] = nil
                print("【队列】任务完成，处理下一个：\(taskId)")
                self.processQueue()
            }
        }
        
        activeRequests[taskId] = requestId
    }
    
    // 取消加载
    func cancelLoading(for id: String) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 取消活跃的请求
            if let requestId = self.activeRequests[id] {
                self.imageManager.cancelImageRequest(requestId)
                self.activeRequests[id] = nil
            }
            
            // 从队列中移除
            self.loadingQueue.removeAll { task in
                task.id == id
            }
            
            // 处理下一个任务
            self.processQueue()
        }
    }
    
    // 根据质量确定目标尺寸
    private func sizeForQuality(_ quality: ImageQuality) -> CGSize {
        switch quality {
        case .thumbnail:
            return CGSize(width: 100, height: 100)
        case .preview:
            return CGSize(width: 500, height: 500)
        case .fullQuality:
            return PHImageManagerMaximumSize
        }
    }
    
    // 清理资源
    func cleanup() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 取消所有活跃的请求
            for (_, requestId) in self.activeRequests {
                self.imageManager.cancelImageRequest(requestId)
            }
            self.activeRequests.removeAll()
            self.loadingQueue.removeAll()
            self.cache.clear()
        }
    }
} 