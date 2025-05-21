import CoreData
import CloudKit

class CoreDataStack {
    static let shared = CoreDataStack()
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        print("CoreDataStack: Setting up persistent cloud kit container...")
        let container = NSPersistentCloudKitContainer(name: "DataModel")
        
        // Configure the CloudKit container options
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.sereda.Expensa"
        )
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("CoreDataStack: Error loading store: \(error), \(error.userInfo)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            print("CoreDataStack: Successfully loaded store at: \(storeDescription.url?.path ?? "unknown")")
        }
        
        // Enable automatic CloudKit sync
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func saveContext() {
        print("CoreDataStack: Saving context...")
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("CoreDataStack: Context saved successfully")
            } catch {
                print("CoreDataStack: Error saving context: \(error)")
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        } else {
            print("CoreDataStack: No changes to save")
        }
    }
}
