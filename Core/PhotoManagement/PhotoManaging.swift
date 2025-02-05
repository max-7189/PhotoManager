import SwiftUI
import Photos

protocol PhotoManaging: ObservableObject {
    var mediaItems: [MediaItem] { get }
    var errorMessage: String? { get }
    var authorizationStatus: PHAuthorizationStatus { get }
    var pendingDeletionsCount: Int { get }
    var pendingKeepsCount: Int { get }
    
    func requestAuthorization()
    func markForDeletion(at index: Int)
    func keepCurrentPhoto(at index: Int)
    func batchDelete()
    func printStatus()
} 