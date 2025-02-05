import UIKit

struct PhotoLoadingConfig {
    // 窗口配置
    static let windowSize = 101          // 保持在内存中的照片数量（当前照片前后各50张）
    static let preloadThreshold = 20     // 触发预加载的阈值
    static let highQualityWindow = 100   // 高质量加载窗口大小（当前照片前后各50张）
    
    // 加载配置
    static let maxConcurrentLoads = 3    // 最大并发加载数
    static let cacheSize = 150           // 缓存大小（确保能容纳完整的窗口）
    
    // 尺寸配置
    static let thumbnailSize = CGSize(width: 100, height: 100)
    static let previewSize = CGSize(width: 500, height: 500)
    
    // 预加载配置
    static let preloadBatchSize = 20     // 每批预加载的数量
    
    // 优先级窗口配置
    static func getPriority(distance: Int) -> LoadingPriority {
        switch distance {
        case 0:
            return .immediate
        case -10...10:
            return .high
        case -30...30:
            return .normal
        default:
            return .low
        }
    }
    
    // 内存压力配置
    static func adjustWindowSize(for memoryLevel: Int) -> Int {
        switch memoryLevel {
        case 0:  // 无压力
            return windowSize
        case 1:  // 低压力
            return windowSize * 3/4
        case 2:  // 高压力
            return windowSize/2
        default: // 严重
            return windowSize/4
        }
    }
    
    // 获取加载范围
    static func getLoadRange(currentIndex: Int, totalCount: Int) -> Range<Int> {
        let start = max(0, currentIndex - highQualityWindow)
        let end = min(totalCount, currentIndex + highQualityWindow + 1)
        return start..<end
    }
    
    // 获取释放范围
    static func getReleaseRange(currentIndex: Int, totalCount: Int) -> Range<Int> {
        return 0..<totalCount
    }
    
    // 获取预加载范围
    static func getPreloadRange(currentIndex: Int, totalCount: Int) -> Range<Int> {
        let start = max(0, currentIndex - highQualityWindow)
        let end = min(totalCount, currentIndex + highQualityWindow + 1)
        return start..<end
    }
} 