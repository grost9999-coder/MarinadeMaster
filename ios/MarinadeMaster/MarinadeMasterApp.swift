import SwiftUI
import SwiftData

@main
struct MarinadeMasterApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: RecipeRecord.self, BatchRecord.self, BatchPhoto.self)
            let context = container.mainContext
            let existing = try context.fetch(FetchDescriptor<RecipeRecord>())
            if existing.isEmpty {
                let seeds = RecipeRecord.seedRecipes
                seeds.forEach(context.insert)
                try context.save()
            }
        } catch {
            fatalError("無法建立本機資料庫：\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}