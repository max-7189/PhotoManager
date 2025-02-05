import Foundation
import Photos

enum PhotoLoadMode: Equatable {
    case all                    // 加载所有照片
    case monthGroup(MonthGroup) // 加载特定月份的照片
    
    var title: String {
        switch self {
        case .all:
            return "所有照片"
        case .monthGroup(let group):
            return "\(group.year)年\(group.month)月"
        }
    }
    
    var assets: [PHAsset] {
        switch self {
        case .all:
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { (asset, _, _) in
                assets.append(asset)
            }
            return assets
        case .monthGroup(let group):
            return group.assets
        }
    }
    
    // 实现Equatable
    static func == (lhs: PhotoLoadMode, rhs: PhotoLoadMode) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all):
            return true
        case (.monthGroup(let lhsGroup), .monthGroup(let rhsGroup)):
            return lhsGroup.id == rhsGroup.id
        default:
            return false
        }
    }
} 