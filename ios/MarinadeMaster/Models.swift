import Foundation
import SwiftData

struct RecipeIngredient: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var group: String
    var name: String
    var amount: Double
    var unit: String
}

struct BatchSnapshot: Codable {
    var recipeName: String
    var recipeVersion: String
    var chickenKg: Double
    var ingredients: [RecipeIngredient]
}

@Model
final class RecipeRecord {
    var id: UUID
    var name: String
    var version: String
    var baseKg: Double
    var note: String
    var ingredientsData: Data
    var createdAt: Date

    init(name: String, version: String, baseKg: Double, note: String, ingredients: [RecipeIngredient]) {
        self.id = UUID()
        self.name = name
        self.version = version
        self.baseKg = baseKg
        self.note = note
        self.ingredientsData = (try? JSONEncoder().encode(ingredients)) ?? Data()
        self.createdAt = .now
    }

    var ingredients: [RecipeIngredient] {
        (try? JSONDecoder().decode([RecipeIngredient].self, from: ingredientsData)) ?? []
    }

    static var seedRecipes: [RecipeRecord] {
        [
            RecipeRecord(name: "紅麴豆乳雞－甜菜根粉版", version: "歷史紀錄／18kg基準", baseKg: 18,
                note: "最新18kg摘要；「磷酸鈉5g或林寶粉」保留原始歧義。",
                ingredients: [
                    .init(group: "濕料", name: "紅麴豆腐乳", amount: 200, unit: "g"),
                    .init(group: "濕料", name: "醬油", amount: 15, unit: "g"),
                    .init(group: "濕料", name: "米酒", amount: 105, unit: "g"),
                    .init(group: "濕料", name: "沙拉油", amount: 36, unit: "g"),
                    .init(group: "濕料", name: "醋", amount: 5, unit: "g"),
                    .init(group: "乾料／粉漿", name: "豆漿粉", amount: 60, unit: "g"),
                    .init(group: "乾料／粉漿", name: "蒜粉", amount: 53, unit: "g"),
                    .init(group: "乾料／粉漿", name: "砂糖", amount: 45, unit: "g"),
                    .init(group: "乾料／粉漿", name: "白胡椒", amount: 18, unit: "g"),
                    .init(group: "乾料／粉漿", name: "甜菜根粉", amount: 5, unit: "g"),
                    .init(group: "乾料／粉漿", name: "磷酸鈉或林寶粉", amount: 5, unit: "g"),
                    .init(group: "乾料／粉漿", name: "中筋麵粉", amount: 150, unit: "g"),
                    .init(group: "乾料／粉漿", name: "地瓜粉", amount: 450, unit: "g"),
                    .init(group: "乾料／粉漿", name: "玉米粉", amount: 300, unit: "g"),
                    .init(group: "乾料／粉漿", name: "冰水", amount: 180, unit: "g"),
                    .init(group: "乾料／粉漿", name: "CMC", amount: 1.8, unit: "g")
                ]),
            RecipeRecord(name: "檸檬雞－熟黃豆粉版", version: "2026-10-05原始紀錄", baseKg: 17,
                note: "原始紀錄明確註記：醃料階段沒有加水。每17kg翅腿。",
                ingredients: [
                    .init(group: "醃料（未加水）", name: "米酒", amount: 255, unit: "g"),
                    .init(group: "醃料（未加水）", name: "醬油", amount: 50, unit: "g"),
                    .init(group: "醃料（未加水）", name: "檸檬酸", amount: 51, unit: "g"),
                    .init(group: "醃料（未加水）", name: "砂糖", amount: 204, unit: "g"),
                    .init(group: "醃料（未加水）", name: "鹽", amount: 136, unit: "g"),
                    .init(group: "醃料（未加水）", name: "熟黃豆粉", amount: 60, unit: "g"),
                    .init(group: "醃料（未加水）", name: "蒜粉", amount: 51, unit: "g"),
                    .init(group: "醃料（未加水）", name: "白胡椒粉", amount: 17, unit: "g")
                ])
        ]
    }
}

@Model
final class BatchRecord {
    var id: UUID
    var code: String
    var recipeName: String
    var recipeVersion: String
    var chickenKg: Double
    var snapshotData: Data
    var stageTimesData: Data
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \BatchPhoto.batch) var photos: [BatchPhoto]

    init(code: String, snapshot: BatchSnapshot) {
        self.id = UUID()
        self.code = code
        self.recipeName = snapshot.recipeName
        self.recipeVersion = snapshot.recipeVersion
        self.chickenKg = snapshot.chickenKg
        self.snapshotData = (try? JSONEncoder().encode(snapshot)) ?? Data()
        self.stageTimesData = Data()
        self.createdAt = .now
        self.photos = []
    }

    var snapshot: BatchSnapshot? {
        try? JSONDecoder().decode(BatchSnapshot.self, from: snapshotData)
    }

    var stageTimes: [String: Date] {
        get { (try? JSONDecoder().decode([String: Date].self, from: stageTimesData)) ?? [:] }
        set { stageTimesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}

@Model
final class BatchPhoto {
    var id: UUID
    @Attribute(.externalStorage) var imageData: Data
    var caption: String
    var createdAt: Date
    var batch: BatchRecord?

    init(imageData: Data, caption: String) {
        self.id = UUID()
        self.imageData = imageData
        self.caption = caption
        self.createdAt = .now
    }
}