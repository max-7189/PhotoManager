import SwiftUI
import Photos

// 月份数据模型
struct MonthGroup: Identifiable {
    let id = UUID()
    let month: Int
    let year: Int
    var assets: [PHAsset]
    var currentPreviewAsset: PHAsset?
    var thumbnail: UIImage?
}

// 年份数据模型
struct YearGroup: Identifiable {
    let id = UUID()
    let year: Int
    var months: [MonthGroup]
    var isExpanded: Bool = true
}

// 照片组管理器
class PhotoGroupModel: ObservableObject {
    @Published var yearGroups: [YearGroup] = []
    @Published var isLoading = false
    private let imageManager = PHImageManager.default()
    private let thumbnailSize = CGSize(width: 200, height: 200)
    
    func loadPhotos() {
        isLoading = true
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let allPhotos = PHAsset.fetchAssets(with: fetchOptions)
        var yearGroupsDict: [Int: [Int: [PHAsset]]] = [:]
        
        // 按年月对照片进行分组
        allPhotos.enumerateObjects { (asset, index, stop) in
            if let date = asset.creationDate {
                let calendar = Calendar.current
                let year = calendar.component(.year, from: date)
                let month = calendar.component(.month, from: date)
                
                if yearGroupsDict[year] == nil {
                    yearGroupsDict[year] = [:]
                }
                if yearGroupsDict[year]?[month] == nil {
                    yearGroupsDict[year]?[month] = []
                }
                yearGroupsDict[year]?[month]?.append(asset)
            }
        }
        
        // 转换为视图模型
        var newYearGroups: [YearGroup] = []
        
        for (year, months) in yearGroupsDict.sorted(by: { $0.key > $1.key }) {
            var monthGroups: [MonthGroup] = []
            
            for (month, assets) in months.sorted(by: { $0.key > $1.key }) {
                let monthGroup = MonthGroup(
                    month: month,
                    year: year,
                    assets: assets,
                    currentPreviewAsset: assets.first
                )
                monthGroups.append(monthGroup)
            }
            
            let yearGroup = YearGroup(year: year, months: monthGroups)
            newYearGroups.append(yearGroup)
        }
        
        DispatchQueue.main.async {
            self.yearGroups = newYearGroups
            self.isLoading = false
            self.loadInitialThumbnails()
        }
    }
    
    private func loadInitialThumbnails() {
        for yearIndex in yearGroups.indices {
            for monthIndex in yearGroups[yearIndex].months.indices {
                loadThumbnailForMonth(yearIndex: yearIndex, monthIndex: monthIndex)
            }
        }
    }
    
    func loadThumbnailForMonth(yearIndex: Int, monthIndex: Int) {
        guard yearGroups.indices.contains(yearIndex),
              yearGroups[yearIndex].months.indices.contains(monthIndex),
              let asset = yearGroups[yearIndex].months[monthIndex].currentPreviewAsset else {
            return
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        imageManager.requestImage(
            for: asset,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            DispatchQueue.main.async {
                self?.yearGroups[yearIndex].months[monthIndex].thumbnail = image
            }
        }
    }
    
    func updateRandomPreview(for yearIndex: Int, monthIndex: Int) {
        guard yearGroups.indices.contains(yearIndex),
              yearGroups[yearIndex].months.indices.contains(monthIndex) else {
            return
        }
        
        let assets = yearGroups[yearIndex].months[monthIndex].assets
        guard let randomAsset = assets.randomElement() else { return }
        
        yearGroups[yearIndex].months[monthIndex].currentPreviewAsset = randomAsset
        loadThumbnailForMonth(yearIndex: yearIndex, monthIndex: monthIndex)
    }
    
    func toggleYearExpansion(_ yearIndex: Int) {
        guard yearGroups.indices.contains(yearIndex) else { return }
        yearGroups[yearIndex].isExpanded.toggle()
    }
} 