import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupArchive: Codable {
    var format: String
    var version: Int
    var exportedAt: Date
    var recipes: [RecipeBackup]
    var batches: [BatchBackup]
}

struct RecipeBackup: Codable {
    var name: String
    var version: String
    var baseKg: Double
    var note: String
    var ingredients: [RecipeIngredient]
    var createdAt: Date

    init(_ recipe: RecipeRecord) {
        name = recipe.name
        version = recipe.version
        baseKg = recipe.baseKg
        note = recipe.note
        ingredients = recipe.ingredients
        createdAt = recipe.createdAt
    }
}

struct BatchBackup: Codable {
    var code: String
    var recipeName: String
    var recipeVersion: String
    var chickenKg: Double
    var snapshot: BatchSnapshot?
    var stageTimes: [String: Date]
    var createdAt: Date
    var photos: [PhotoBackup]

    init(_ batch: BatchRecord) {
        code = batch.code
        recipeName = batch.recipeName
        recipeVersion = batch.recipeVersion
        chickenKg = batch.chickenKg
        snapshot = batch.snapshot
        stageTimes = batch.stageTimes
        createdAt = batch.createdAt
        photos = batch.photos.map(PhotoBackup.init)
    }
}

struct PhotoBackup: Codable {
    var imageData: Data
    var caption: String
    var createdAt: Date

    init(_ photo: BatchPhoto) {
        imageData = photo.imageData
        caption = photo.caption
        createdAt = photo.createdAt
    }
}

struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var context
    @Query private var recipes: [RecipeRecord]
    @Query private var batches: [BatchRecord]

    @State private var exportDocument: BackupFileDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingArchive: BackupArchive?
    @State private var showImportConfirm = false
    @State private var statusMessage = ""
    @State private var showStatus = false

    var body: some View {
        NavigationStack {
            List {
                Section("本機資料概況") {
                    LabeledContent("配方版本", value: "\(recipes.count) 筆")
                    LabeledContent("生產批次", value: "\(batches.count) 筆")
                    LabeledContent("批次照片", value: "\(batches.reduce(0) { $0 + $1.photos.count }) 張")
                }
                Section("完整備份") {
                    Button {
                        makeBackup()
                    } label: {
                        Label("匯出完整 JSON 備份", systemImage: "square.and.arrow.up")
                    }
                    .disabled(showExporter)
                    Button {
                        showImporter = true
                    } label: {
                        Label("匯入備份並還原", systemImage: "square.and.arrow.down")
                    }
                    Text("備份包含所有配方版本、生產批次、製程時間與照片原始資料。請將匯出檔另存到「檔案」App 或外接儲存空間。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("重要提醒") {
                    Label("匯入會取代目前 App 內所有配方與批次資料。", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("建議每週備份一次；更換手機或刪除 App 前，先確認備份檔已成功保存。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("本機備份")
            .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json, defaultFilename: "MarinadeMaster-Backup-\(Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash)))") { result in
                switch result {
                case .success(let url):
                    statusMessage = "備份已匯出：\(url.lastPathComponent)"
                case .failure(let error):
                    statusMessage = "匯出失敗：\(error.localizedDescription)"
                }
                showStatus = true
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                loadBackup(result)
            }
            .confirmationDialog("確定還原備份？", isPresented: $showImportConfirm, titleVisibility: .visible) {
                Button("取代目前資料並還原", role: .destructive) { restoreBackup() }
                Button("取消", role: .cancel) { pendingArchive = nil }
            } message: {
                if let archive = pendingArchive {
                    Text("將匯入 \(archive.recipes.count) 個配方版本、\(archive.batches.count) 個批次及 \(archive.batches.reduce(0) { $0 + $1.photos.count }) 張照片。此操作會取代目前資料。")
                }
            }
            .alert("備份狀態", isPresented: $showStatus) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(statusMessage)
            }
        }
    }

    private func makeBackup() {
        do {
            let archive = BackupArchive(
                format: "MarinadeMaster",
                version: 1,
                exportedAt: .now,
                recipes: recipes.map(RecipeBackup.init),
                batches: batches.map(BatchBackup.init)
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            exportDocument = BackupFileDocument(data: try encoder.encode(archive))
            showExporter = true
        } catch {
            statusMessage = "建立備份失敗：\(error.localizedDescription)"
            showStatus = true
        }
    }

    private func loadBackup(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let archive = try decoder.decode(BackupArchive.self, from: data)
            guard archive.format == "MarinadeMaster", archive.version == 1,
                  archive.recipes.allSatisfy({ $0.baseKg > 0 && !$0.name.isEmpty }),
                  archive.batches.allSatisfy({ $0.chickenKg > 0 }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            pendingArchive = archive
            showImportConfirm = true
        } catch {
            statusMessage = "無法讀取備份：\(error.localizedDescription)"
            showStatus = true
        }
    }

    private func restoreBackup() {
        guard let archive = pendingArchive else { return }
        do {
            for item in try context.fetch(FetchDescriptor<BatchRecord>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<RecipeRecord>()) { context.delete(item) }

            for item in archive.recipes {
                context.insert(RecipeRecord(name: item.name, version: item.version, baseKg: item.baseKg, note: item.note, ingredients: item.ingredients))
            }
            for item in archive.batches {
                let snapshot = item.snapshot ?? BatchSnapshot(recipeName: item.recipeName, recipeVersion: item.recipeVersion, chickenKg: item.chickenKg, ingredients: [])
                let batch = BatchRecord(code: item.code, snapshot: snapshot)
                batch.stageTimes = item.stageTimes
                for photoItem in item.photos {
                    let photo = BatchPhoto(imageData: photoItem.imageData, caption: photoItem.caption)
                    photo.batch = batch
                    batch.photos.append(photo)
                }
                context.insert(batch)
            }
            try context.save()
            pendingArchive = nil
            statusMessage = "還原完成：\(archive.recipes.count) 個配方版本、\(archive.batches.count) 個批次、\(archive.batches.reduce(0) { $0 + $1.photos.count }) 張照片。"
        } catch {
            context.rollback()
            statusMessage = "還原失敗，已嘗試取消未提交的變更：\(error.localizedDescription)"
        }
        showStatus = true
    }
}
