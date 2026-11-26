import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import AVFoundation

struct ContentView: View {
    var body: some View {
        TabView {
            RecipeListView()
                .tabItem { Label("配方", systemImage: "book.closed") }
            BatchListView()
                .tabItem { Label("生產批次", systemImage: "clipboard") }
            InventoryView()
                .tabItem { Label("庫存", systemImage: "shippingbox") }
            BackupRestoreView()
                .tabItem { Label("備份", systemImage: "externaldrive") }
        }
        .tint(Color(red: 0.09, green: 0.42, blue: 0.29))
    }
}

struct RecipeListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecipeRecord.createdAt, order: .reverse) private var recipes: [RecipeRecord]
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(recipes) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(recipe.name).font(.headline)
                                Text("\(recipe.version)・基準 \(recipe.baseKg.formatted()) kg")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("配方版本（編輯時另存新版本）")
                }
            }
            .navigationTitle("醃製配方")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditor = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showEditor) { RecipeEditorView() }
        }
    }
}

struct RecipeDetailView: View {
    let recipe: RecipeRecord
    @State private var showEditor = false
    @State private var showBatch = false
    private var ingredients: [RecipeIngredient] { recipe.ingredients }

    var body: some View {
        List {
            Section("配方資訊") {
                LabeledContent("版本", value: recipe.version)
                LabeledContent("基準雞肉", value: "\(recipe.baseKg.formatted()) kg")
                if !recipe.note.isEmpty { Text(recipe.note).font(.footnote).foregroundStyle(.secondary) }
            }
            ForEach(Dictionary(grouping: ingredients, by: \.group).keys.sorted(), id: \.self) { group in
                Section(group) {
                    ForEach(ingredients.filter { $0.group == group }) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text("\(item.amount.formatted()) \(item.unit)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                Button("依此配方建立生產批次") { showBatch = true }
                    .fontWeight(.semibold)
            }
        }
        .navigationTitle(recipe.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("另存新版本") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) { RecipeEditorView(source: recipe) }
        .sheet(isPresented: $showBatch) { CreateBatchView(recipe: recipe) }
    }
}

struct RecipeEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let source: RecipeRecord?
    @State private var name: String
    @State private var version: String
    @State private var baseKg: String
    @State private var note: String
    @State private var ingredients: [RecipeIngredient]

    init(source: RecipeRecord? = nil) {
        self.source = source
        _name = State(initialValue: source?.name ?? "")
        _version = State(initialValue: source == nil ? "v1" : source!.version + "（編輯另存）")
        _baseKg = State(initialValue: String(source?.baseKg ?? 18))
        _note = State(initialValue: source?.note ?? "")
        _ingredients = State(initialValue: source?.ingredients ?? [RecipeIngredient(group: "醃料", name: "", amount: 0, unit: "g")])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("配方基本資料") {
                    TextField("配方名稱", text: $name)
                    TextField("版本", text: $version)
                    TextField("基準雞肉重量（kg）", text: $baseKg).keyboardType(.decimalPad)
                    TextField("備註", text: $note, axis: .vertical)
                }
                Section("原料明細") {
                    ForEach($ingredients) { $item in
                        VStack(alignment: .leading) {
                            TextField("群組（例如：濕料）", text: $item.group)
                            TextField("原料名稱", text: $item.name)
                            HStack {
                                TextField("用量", value: $item.amount, format: .number)
                                    .keyboardType(.decimalPad)
                                Picker("單位", selection: $item.unit) {
                                    Text("g").tag("g")
                                    Text("kg").tag("kg")
                                }.pickerStyle(.segmented).frame(maxWidth: 120)
                            }
                        }
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }
                    Button { ingredients.append(.init(group: "醃料", name: "", amount: 0, unit: "g")) } label: {
                        Label("新增原料", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle(source == nil ? "新增配方" : "另存配方版本")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("儲存") { save() } }
            }
        }
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !version.trimmingCharacters(in: .whitespaces).isEmpty,
              let base = Double(baseKg), base > 0,
              !ingredients.isEmpty,
              ingredients.allSatisfy({ !$0.group.trimmingCharacters(in: .whitespaces).isEmpty && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && $0.amount > 0 && ["g", "kg"].contains($0.unit) }) else { return }
        context.insert(RecipeRecord(name: name, version: version, baseKg: base, note: note, ingredients: ingredients))
        dismiss()
    }
}

struct CreateBatchView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let recipe: RecipeRecord
    @State private var chickenKg = "18"
    @Query private var inventoryItems: [InventoryItem]
    @State private var showShortage = false
    @State private var shortageMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("生產批次") {
                    LabeledContent("配方", value: recipe.name)
                    LabeledContent("配方版本", value: recipe.version)
                    TextField("雞肉重量（kg）", text: $chickenKg).keyboardType(.decimalPad)
                }
                if let kg = Double(chickenKg), kg > 0 {
                    Section("換算預覽") {
                        ForEach(scaledIngredients(kg), id: \.id) { item in
                            HStack {
                                Text(item.group + "／" + item.name)
                                Spacer()
                                Text("\(item.amount.formatted()) \(item.unit)")
                            }.font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle("建立批次")
            .alert("庫存不足，無法扣料", isPresented: $showShortage) {
                Button("知道了", role: .cancel) {}
            } message: { Text(shortageMessage) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") { create() }.disabled(!(Double(chickenKg).map { $0 > 0 } ?? false))
                }
            }
        }
    }

    private func scaledIngredients(_ kg: Double) -> [RecipeIngredient] {
        recipe.ingredients.map {
            RecipeIngredient(group: $0.group, name: $0.name, amount: $0.amount * kg / recipe.baseKg, unit: $0.unit)
        }
    }

    private func create() {
        guard let kg = Double(chickenKg), kg > 0 else { return }
        let ingredients = scaledIngredients(kg)
        var deductions: [UUID: Double] = [:]
        var shortages: [String] = []
        var costLines: [BatchCostSnapshotLine] = []

        for ingredient in ingredients {
            guard let item = inventoryItems.first(where: {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
                ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }), let amount = convertedAmount(ingredient, to: item.unit) else { continue }
            deductions[item.id, default: 0] += amount
        }

        for item in inventoryItems {
            guard let amount = deductions[item.id], amount > 0 else { continue }
            if item.onHand + 0.0000001 < amount {
                shortages.append("\(item.name)：需要 \(amount.formatted()) \(item.unit)，庫存 \(item.onHand.formatted()) \(item.unit)")
            } else {
                costLines.append(BatchCostSnapshotLine(
                    ingredientName: item.name,
                    quantity: amount,
                    unit: item.unit,
                    unitCost: item.averageCost,
                    totalCost: amount * item.averageCost
                ))
            }
        }

        if !shortages.isEmpty {
            shortageMessage = shortages.joined(separator: "\n")
            showShortage = true
            return
        }

        let snapshot = BatchSnapshot(recipeName: recipe.name, recipeVersion: recipe.version, chickenKg: kg, ingredients: ingredients)
        let code = "MM-" + Date.now.formatted(.dateTime.year().month().day().hour().minute())
        let batch = BatchRecord(code: code, snapshot: snapshot)
        batch.costSnapshot = costLines
        for item in inventoryItems {
            guard let amount = deductions[item.id], amount > 0 else { continue }
            item.onHand -= amount
            item.updatedAt = .now
        }
        context.insert(batch)
        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
        }
    }

    private func convertedAmount(_ ingredient: RecipeIngredient, to inventoryUnit: String) -> Double? {
        if ingredient.unit == inventoryUnit { return ingredient.amount }
        if ingredient.unit == "g" && inventoryUnit == "kg" { return ingredient.amount / 1000 }
        if ingredient.unit == "kg" && inventoryUnit == "g" { return ingredient.amount * 1000 }
        return nil
    }
}

struct BatchListView: View {
    @Query(sort: \BatchRecord.createdAt, order: .reverse) private var batches: [BatchRecord]

    var body: some View {
        NavigationStack {
            List {
                ForEach(batches) { batch in
                    NavigationLink {
                        BatchDetailView(batch: batch)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(batch.code).font(.headline)
                            Text("\(batch.recipeName)・\(batch.chickenKg.formatted()) kg")
                            Text(batch.recipeVersion).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("生產批次")
        }
    }
}

struct BatchDetailView: View {
    @Environment(\.modelContext) private var context
    let batch: BatchRecord
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var cameraImage: UIImage?
    @State private var showCamera = false
    @State private var showCameraUnavailable = false
    @State private var cameraNeedsSettings = false
    @State private var cameraMessage = ""
    @State private var photoMessage = ""
    @State private var showPhotoMessage = false
    @State private var caption = "生產照片"

    private let stages = ["退冰", "醃製", "裹粉", "完成"]

    var body: some View {
        List {
            Section("批次資訊") {
                LabeledContent("配方", value: batch.recipeName)
                LabeledContent("版本", value: batch.recipeVersion)
                LabeledContent("雞肉重量", value: "\(batch.chickenKg.formatted()) kg")
            }
            if !batch.costSnapshot.isEmpty {
                Section("批次原料成本快照") {
                    ForEach(Array(batch.costSnapshot.enumerated()), id: \.offset) { entry in
                        let line = entry.element
                        HStack {
                            VStack(alignment: .leading) {
                                Text(line.ingredientName)
                                Text("\(line.quantity.formatted()) \(line.unit) × \(line.unitCost.formatted(.currency(code: "TWD")))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(line.totalCost.formatted(.currency(code: "TWD")))
                        }
                    }
                    LabeledContent("已追蹤原料成本", value: batch.costSnapshot.reduce(0) { $0 + $1.totalCost }.formatted(.currency(code: "TWD")))
                }
            }
            if let snapshot = batch.snapshot {
                ForEach(Dictionary(grouping: snapshot.ingredients, by: \.group).keys.sorted(), id: \.self) { group in
                    Section(group) {
                        ForEach(snapshot.ingredients.filter { $0.group == group }) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("\(item.amount.formatted()) \(item.unit)").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Section("製程時間") {
                ForEach(stages, id: \.self) { stage in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(stage)
                            if let time = batch.stageTimes[stage] {
                                Text(time.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("記錄") {
                            var values = batch.stageTimes
                            values[stage] = .now
                            batch.stageTimes = values
                            try? context.save()
                        }
                    }
                }
            }
            Section("批次照片") {
                TextField("照片備註", text: $caption)
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("從相簿選取照片", systemImage: "photo")
                }
                Button {
                    requestCameraAccess()
                } label: {
                    Label("使用相機拍照", systemImage: "camera")
                }
                ForEach(batch.photos) { photo in
                    HStack {
                        if let image = UIImage(data: photo.imageData) {
                            Image(uiImage: image).resizable().scaledToFill().frame(width: 72, height: 72).clipped().cornerRadius(8)
                        }
                        VStack(alignment: .leading) {
                            Text(photo.caption)
                            Text(photo.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) { context.delete(photo) } label: { Image(systemName: "trash") }
                    }
                }
                .onDelete { offsets in for offset in offsets { context.delete(batch.photos[offset]) } }
            }
        }
        .navigationTitle(batch.code)
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $cameraImage)
        }
        .alert("此裝置沒有可用相機", isPresented: $showCameraUnavailable) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(cameraMessage.isEmpty ? "可改用「從相簿選取照片」加入批次紀錄。" : cameraMessage)
        }
        .alert("相機權限未開啟", isPresented: $cameraNeedsSettings) {
            Button("前往設定") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button("改用相簿", role: .cancel) {}
        } message: {
            Text(cameraMessage)
        }
        .alert("照片紀錄", isPresented: $showPhotoMessage) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(photoMessage)
        }
        .onChange(of: cameraImage) { _, image in
            guard let image else { return }
            savePhoto(image)
            cameraImage = nil
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    savePhoto(image)
                } catch {
                    photoMessage = "讀取相簿照片失敗：\(error.localizedDescription)"
                    showPhotoMessage = true
                }
                selectedPhoto = nil
            }
        }
    }

    private func requestCameraAccess() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraMessage = "此裝置沒有可用相機，可改用「從相簿選取照片」。"
            showCameraUnavailable = true
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        cameraMessage = "請在 iPhone「設定 > MarinadeMaster > 相機」允許相機權限，或改用相簿選取。"
                        cameraNeedsSettings = true
                    }
                }
            }
        case .denied, .restricted:
            cameraMessage = "相機權限目前未允許。可前往設定開啟權限，或改用相簿選取照片。"
            cameraNeedsSettings = true
        @unknown default:
            cameraMessage = "無法確認相機權限，可改用相簿選取照片。"
            showCameraUnavailable = true
        }
    }

    private func savePhoto(_ image: UIImage) {
        let maxDimension: CGFloat = 1600
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let compressed = renderer.jpegData(withCompressionQuality: 0.72) { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard !compressed.isEmpty else {
            photoMessage = "照片壓縮失敗，原有批次資料未變更。請重試或改選其他照片。"
            showPhotoMessage = true
            return
        }
        let photo = BatchPhoto(imageData: compressed, caption: caption)
        photo.batch = batch
        batch.photos.append(photo)
        do {
            try context.save()
            photoMessage = "照片已加入 \(batch.code) 批次。"
        } catch {
            context.delete(photo)
            batch.photos.removeAll { $0.id == photo.id }
            photoMessage = "照片未能儲存：\(error.localizedDescription)"
        }
        showPhotoMessage = true
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
