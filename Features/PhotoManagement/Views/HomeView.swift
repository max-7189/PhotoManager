import SwiftUI
import Photos

struct HomeView: View {
    @StateObject private var photoGroupModel = PhotoGroupModel()
    @State private var selectedMonthTimer: Timer?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 所有照片入口
                    NavigationLink(destination: PhotoDetailView(loadMode: .all)) {
                        allPhotosCard
                    }
                    
                    // 按月份浏览
                    monthlyBrowseSection
                }
                .padding()
            }
            .navigationTitle("照片库")
            .onAppear {
                checkPhotoLibraryPermission()
            }
        }
    }
    
    private var allPhotosCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.blue.opacity(0.1))
            
            VStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("所有照片")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding()
        }
        .frame(height: 150)
    }
    
    private var monthlyBrowseSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("按月份浏览")
                .font(.title2)
                .bold()
            
            if photoGroupModel.isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                yearGroupsView
            }
        }
    }
    
    private var yearGroupsView: some View {
        VStack(spacing: 20) {
            ForEach(Array(photoGroupModel.yearGroups.enumerated()), id: \.element.id) { yearIndex, yearGroup in
                yearSection(yearIndex: yearIndex, yearGroup: yearGroup)
            }
        }
    }
    
    private func yearSection(yearIndex: Int, yearGroup: YearGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 年份标题栏
            Button(action: {
                photoGroupModel.toggleYearExpansion(yearIndex)
            }) {
                HStack {
                    Text("\(yearGroup.year)年")
                        .font(.title3)
                        .bold()
                    
                    Spacer()
                    
                    Image(systemName: yearGroup.isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            .foregroundColor(.primary)
            
            if yearGroup.isExpanded {
                monthsScrollView(yearIndex: yearIndex, months: yearGroup.months)
            }
        }
    }
    
    private func monthsScrollView(yearIndex: Int, months: [MonthGroup]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(Array(months.enumerated()), id: \.element.id) { monthIndex, month in
                    monthCard(yearIndex: yearIndex, monthIndex: monthIndex, month: month)
                }
            }
            .padding(.horizontal, 5)
        }
    }
    
    private func monthCard(yearIndex: Int, monthIndex: Int, month: MonthGroup) -> some View {
        NavigationLink(destination: PhotoDetailView(loadMode: .monthGroup(month))) {
            VStack {
                if let thumbnail = month.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipped()
                } else {
                    ProgressView()
                        .frame(width: 150, height: 150)
                }
                
                Text("\(month.month)月")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(month.assets.count)张照片")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 150)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(15)
            .onAppear {
                startRandomPreviewTimer(for: yearIndex, monthIndex: monthIndex)
            }
            .onDisappear {
                stopRandomPreviewTimer()
            }
        }
    }
    
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if status == .authorized || status == .limited {
                    DispatchQueue.main.async {
                        self.photoGroupModel.loadPhotos()
                    }
                }
            }
        case .authorized, .limited:
            photoGroupModel.loadPhotos()
        default:
            break
        }
    }
    
    private func startRandomPreviewTimer(for yearIndex: Int, monthIndex: Int) {
        stopRandomPreviewTimer()
        selectedMonthTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            photoGroupModel.updateRandomPreview(for: yearIndex, monthIndex: monthIndex)
        }
    }
    
    private func stopRandomPreviewTimer() {
        selectedMonthTimer?.invalidate()
        selectedMonthTimer = nil
    }
}

// 临时的设置视图（后续会移到单独的文件）
struct SettingsView: View {
    var body: some View {
        Text("设置")
            .navigationTitle("设置")
    }
}

#Preview {
    HomeView()
} 