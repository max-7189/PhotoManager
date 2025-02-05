import SwiftUI
import Photos

struct PhotoDetailView: View {
    @StateObject private var viewModel: PhotoViewModel
    @Environment(\.presentationMode) var presentationMode
    
    init(loadMode: PhotoLoadMode) {
        _viewModel = StateObject(wrappedValue: PhotoViewModel(loadMode: loadMode))
    }
    
    var body: some View {
        ZStack {
            if viewModel.isInitialLoading {
                loadingView
            } else {
                TabView(selection: $viewModel.currentIndex) {
                    ForEach(Array(viewModel.mediaItems.enumerated()), id: \.element.id) { index, item in
                        mediaCard(for: item, at: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: viewModel.currentIndex) { newIndex in
                    viewModel.handleScroll(currentIndex: newIndex)
                }
            }
            
            if !viewModel.isInitialLoading {
                overlayButtons
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
        }
    }
    
    private func mediaCard(for item: MediaItem, at index: Int) -> some View {
        Group {
            if item.isVideo {
                VideoCard(
                    item: item,
                    markStatus: item.markStatus,
                    onDelete: { viewModel.markForDeletion(at: index) },
                    onKeep: { viewModel.keepCurrentPhoto(at: index) }
                )
            } else {
                PhotoCard(
                    item: item,
                    markStatus: item.markStatus,
                    onDelete: { viewModel.markForDeletion(at: index) },
                    onKeep: { viewModel.keepCurrentPhoto(at: index) }
                )
            }
        }
    }
    
    private var overlayButtons: some View {
        VStack {
            Spacer()
            HStack {
                Button(action: { viewModel.markForDeletion(at: viewModel.currentIndex) }) {
                    Image(systemName: "trash")
                        .font(.title)
                        .foregroundColor(.red)
                        .padding()
                        .background(Circle().fill(.ultraThinMaterial))
                }
                
                Spacer()
                
                Button(action: { viewModel.keepCurrentPhoto(at: viewModel.currentIndex) }) {
                    Image(systemName: "star")
                        .font(.title)
                        .foregroundColor(.yellow)
                        .padding()
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
    
    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left")
                .imageScale(.large)
        }
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
} 