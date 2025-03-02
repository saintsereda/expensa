import CoreData

class CoreDataStack {
    static let shared = CoreDataStack()
    
    lazy var persistentContainer: NSPersistentContainer = {
        print("CoreDataStack: Setting up persistent container...")
        let container = NSPersistentContainer(name: "DataModel")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("CoreDataStack: Error loading store: \(error), \(error.userInfo)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            print("CoreDataStack: Successfully loaded store at: \(storeDescription.url?.path ?? "unknown")")
        }
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
