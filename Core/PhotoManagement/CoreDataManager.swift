import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    let persistentContainer: NSPersistentContainer
    private var isStoreLoaded = false
    private var loadCompletion: ((Error?) -> Void)?
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "PhotoDataMode")
        loadStore()
    }
    
    private func loadStore() {
        persistentContainer.loadPersistentStores { [weak self] (description, error) in
            self?.isStoreLoaded = error == nil
            if let error = error {
                print("Unable to load persistent stores: \(error)")
            }
            self?.loadCompletion?(error)
        }
    }
    
    func waitForStore() async throws {
        if isStoreLoaded { return }
        
        return try await withCheckedThrowingContinuation { continuation in
            loadCompletion = { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
} 
