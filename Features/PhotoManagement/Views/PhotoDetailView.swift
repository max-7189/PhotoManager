//
//  ContentView.swift
//  photosTest
//
//  Created by 赵子源 on 2024/12/25.
//

// 导入必要的框架
import SwiftUI   // 用于构建用户界面
import Photos    // 用于访问和管理照片库
import AVKit     // 用于处理音视频播放

struct PhotoDetailView: View {
    let loadMode: PhotoLoadMode
    @StateObject private var viewModel: PhotoViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(loadMode: PhotoLoadMode) {
        self.loadMode = loadMode
        _viewModel = StateObject(wrappedValue: PhotoViewModel(loadMode: loadMode))
    }
    
    var body: some View {
        ZStack {
            switch viewModel.viewState {
            case .loading:
                loadingView
            case .loaded:
                mainContentView
            case .error(let message):
                errorView(message)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                deleteButton
            }
        }
        .alert("确认删除", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("删除", role: .destructive) {
                viewModel.confirmDelete()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除选中的照片吗？")
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("加载媒体中...")
                .foregroundColor(.secondary)
                .padding(.top)
            Text("\(Int(viewModel.loadingProgress * 100))%")
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
    
    private var mainContentView: some View {
        VStack {
            TabView(selection: $viewModel.currentIndex) {
                ForEach(Array(viewModel.mediaItems.enumerated()), id: \.element.id) { index, item in
                    mediaCard(item: item, index: index)
                        .tag(index)
                        .gesture(item.isVideo ? nil : dragGesture(enabled: index == viewModel.currentIndex))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: viewModel.currentIndex) { newIndex in
                viewModel.handleScroll(currentIndex: newIndex)
            }
            
            ThumbnailStrip(
                items: viewModel.mediaItems,
                currentIndex: viewModel.currentIndex,
                onThumbnailTap: viewModel.handleThumbnailTap
            )
            .frame(height: 80)
            .padding(.bottom)
            
            controlButtons
        }
    }
    
    private var mediaCardsView: some View {
        ZStack {
            ForEach(Array(viewModel.currentItems.enumerated()), id: \.element.id) { index, item in
                mediaCard(item: item, index: index)
            }
        }
        .overlay(debugOverlay, alignment: .top)
    }
    
    private func mediaCard(item: MediaItem, index: Int) -> some View {
        let cardView: AnyView = if item.isVideo {
            AnyView(
                VideoCard(mediaItem: item,
                         offset: index == viewModel.currentIndex ? viewModel.offset : .zero,
                         isCurrentVideo: index == viewModel.currentIndex,
                         photoManager: viewModel.imageManager)
                    .id(item.id)
                    .zIndex(index == viewModel.currentIndex ? 1 : 0)
            )
        } else {
            AnyView(
                PhotoCard(photo: item,
                         offset: index == viewModel.currentIndex ? viewModel.offset : .zero,
                         isCurrentPhoto: index == viewModel.currentIndex,
                         photoManager: viewModel.imageManager)
                    .id(item.id)
                    .zIndex(index == viewModel.currentIndex ? 1 : 0)
                    .gesture(dragGesture(enabled: index == viewModel.currentIndex))
            )
        }
        return cardView
    }
    
    private var debugOverlay: some View {
        VStack {
            Text("当前索引: \(viewModel.currentIndex)")
            Text("剩余照片: \(viewModel.mediaItems.count)")
            if let currentPhoto = viewModel.currentItems.first {
                Text("当前照片ID: \(currentPhoto.id)")
            }
        }
        .font(.caption)
        .foregroundColor(.gray)
        .padding()
    }
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            Button(action: {
                guard !viewModel.isAnimating else { return }
                viewModel.handleDelete()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(viewModel.isAnimating ? .gray : .red)
            }
            
            Button(action: {
                guard !viewModel.isAnimating else { return }
                viewModel.handleKeep()
            }) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(viewModel.isAnimating ? .gray : .green)
            }
        }
        .padding()
    }
    
    private var deleteButton: some View {
        Button(action: {
            viewModel.showDeleteConfirmation()
        }) {
            Text("删除")
                .foregroundColor(.red)
        }
        .disabled(viewModel.pendingDeletionsCount == 0)
    }
    
    private var batchDeleteButton: some View {
        Button(action: {
            viewModel.confirmDelete()
        }) {
            Text("删除选中的照片")
                .foregroundColor(.red)
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.red))
        }
        .disabled(viewModel.pendingDeletionsCount == 0)
        .padding(.horizontal)
    }
    
    private func dragGesture(enabled: Bool) -> some Gesture {
        DragGesture()
            .onChanged { gesture in
                guard !viewModel.isAnimating && enabled else { return }
                viewModel.offset = gesture.translation
            }
            .onEnded { gesture in
                guard !viewModel.isAnimating && enabled else { return }
                let translation = gesture.translation.width
                
                if abs(translation) > 100 {
                    viewModel.isAnimating = true
                    
                    if translation > 0 {
                        // 右滑保留
                        withAnimation(.easeOut(duration: 0.3)) {
                            viewModel.offset = CGSize(width: 500, height: 0)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            viewModel.handleKeep()
                            withAnimation(.spring()) {
                                viewModel.offset = .zero
                                viewModel.isAnimating = false
                            }
                        }
                    } else {
                        // 左滑删除
                        withAnimation(.easeOut(duration: 0.3)) {
                            viewModel.offset = CGSize(width: -500, height: 0)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            viewModel.handleDelete()
                            withAnimation(.spring()) {
                                viewModel.offset = .zero
                                viewModel.isAnimating = false
                            }
                        }
                    }
                } else {
                    // 滑动距离不够，回弹
                    withAnimation(.spring()) {
                        viewModel.offset = .zero
                        viewModel.isAnimating = false
                    }
                }
            }
    }
    
    private var emptyView: some View {
        Text("没有找到照片")
            .foregroundColor(.gray)
    }
    
    private func errorView(_ error: String) -> some View {
        Text(error)
            .foregroundColor(.red)
            .padding()
    }
    
    private var backButton: some View {
        Button(action: {
            dismiss()
        }) {
            Image(systemName: "chevron.left")
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    PhotoDetailView(loadMode: .all)
}
