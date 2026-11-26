import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ContentView: View {
    var body: some View {
        TabView {
            RecipeListView()
                .tabItem { Label("配方", systemImage: "book.closed") }
            BatchListView()
                .tabItem { Label("生產批次", systemImage: "clipboard") }
        }
        .tint(Color(red: 0.09, green: 0.42, blue: 0.29))
    }
}

struct RecipeListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \\RecipeRecord.createdAt, order: .reverse) private var recipes: [RecipeRecord]
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
            ForEach(Dictionary(grouping: ingredients, by: \\.group).keys.sorted(), id: \\.self) { group in
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
                        ForEach(scaledIngredients(kg), id: \\.id) { item in
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
        let snapshot = BatchSnapshot(recipeName: recipe.name, recipeVersion: recipe.version, chickenKg: kg, ingredients: scaledIngredients(kg))
        let code = "MM-" + Date.now.formatted(.dateTime.year().month().day().hour().minute())
        context.insert(BatchRecord(code: code, snapshot: snapshot))
        dismiss()
    }
}

struct BatchListView: View {
    @Query(sort: \\BatchRecord.createdAt, order: .reverse) private var batches: [BatchRecord]

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
    @State private var caption = "生產照片"

    private let stages = ["退冰", "醃製", "裹粉", "完成"]

    var body: some View {
        List {
            Section("批次資訊") {
                LabeledContent("配方", value: batch.recipeName)
                LabeledContent("版本", value: batch.recipeVersion)
                LabeledContent("雞肉重量", value: "\(batch.chickenKg.formatted()) kg")
            }
            if let snapshot = batch.snapshot {
                ForEach(Dictionary(grouping: snapshot.ingredients, by: \\.group).keys.sorted(), id: \\.self) { group in
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
                ForEach(stages, id: \\.self) { stage in
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
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                let maxDimension: CGFloat = 1600
                let scale = min(1, maxDimension / max(image.size.width, image.size.height))
                let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                let compressed = renderer.jpegData(withCompressionQuality: 0.72) { _ in
                    image.draw(in: CGRect(origin: .zero, size: targetSize))
                }
                let photo = BatchPhoto(imageData: compressed, caption: caption)
                photo.batch = batch
                batch.photos.append(photo)
                try? context.save()
                selectedPhoto = nil
            }
        }
    }
}