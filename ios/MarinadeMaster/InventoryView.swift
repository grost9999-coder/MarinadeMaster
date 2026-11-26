import SwiftUI
import SwiftData

struct InventoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Query(sort: \InventoryPurchase.createdAt, order: .reverse) private var purchases: [InventoryPurchase]
    @State private var showingAdd = false
    @State private var showingPurchase = false
    @State private var selectedItem: InventoryItem?

    var body: some View {
        NavigationStack {
            List {
                Section("原料庫存") {
                    if items.isEmpty {
                        ContentUnavailableView("尚無庫存原料", systemImage: "shippingbox", description: Text("先新增原料，再登記進貨。"))
                    }
                    ForEach(Array(items), id: \InventoryItem.id) { item in
                        HStack {
                            Button { selectedItem = item } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(item.name).font(.headline)
                                        Spacer()
                                        Text(item.onHand, format: .number)
                                        Text(" " + item.unit)
                                    }
                                    .foregroundColor(item.onHand > 0 ? Color.primary : Color.orange)
                                    HStack(spacing: 3) {
                                        Text("平均單位成本：")
                                        Text(item.averageCost, format: .currency(code: "TWD"))
                                        Text("/" + item.unit)
                                    }
                                    .font(.caption).foregroundStyle(.secondary)
                                }
                            }.buttonStyle(.plain)
                            Button(role: .destructive) {
                                context.delete(item)
                                try? context.save()
                            } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                        }
                    }
                }
                Section("進貨紀錄") {
                    ForEach(Array(purchases.prefix(30)), id: \InventoryPurchase.id) { purchase in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(purchase.itemName).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(purchase.totalCost.formatted(.currency(code: "TWD")))
                            }
                            Text("\(purchase.quantity.formatted()) \(purchase.unit) × \(purchase.unitPrice.formatted(.currency(code: "TWD")))")
                                .font(.caption).foregroundStyle(.secondary)
                            if !purchase.supplier.isEmpty {
                                Text(purchase.supplier).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("庫存與進貨")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingPurchase = true } label: { Label("進貨", systemImage: "cart.badge.plus") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) { InventoryItemEditorView() }
            .sheet(isPresented: $showingPurchase) { PurchaseEntryView(items: items) }
            .sheet(item: $selectedItem) { item in InventoryItemEditorView(item: item) }
        }
    }
}

struct InventoryItemEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let item: InventoryItem?
    @State private var name: String
    @State private var unit: String
    @State private var quantity: String
    @State private var averageCost: String

    init(item: InventoryItem? = nil) {
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _unit = State(initialValue: item?.unit ?? "g")
        _quantity = State(initialValue: item.map { String($0.onHand) } ?? "0")
        _averageCost = State(initialValue: item.map { String($0.averageCost) } ?? "0")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("原料資料") {
                    TextField("原料名稱", text: $name)
                    Picker("庫存單位", selection: $unit) {
                        Text("g").tag("g")
                        Text("kg").tag("kg")
                        Text("個／包／瓶").tag("個")
                    }
                    TextField("目前庫存", text: $quantity).keyboardType(.decimalPad)
                    TextField("平均單位成本（元／單位）", text: $averageCost).keyboardType(.decimalPad)
                }
                if item != nil {
                    Text("直接調整庫存會保留平均成本；正式盤點差異紀錄功能仍待補。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(item == nil ? "新增庫存原料" : "編輯庫存原料")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("儲存", action: save) }
            }
        }
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              let qty = Double(quantity), qty >= 0,
              let cost = Double(averageCost), cost >= 0 else { return }
        if let item {
            item.name = name.trimmingCharacters(in: .whitespaces)
            item.unit = unit
            item.onHand = qty
            item.averageCost = cost
        } else {
            context.insert(InventoryItem(name: name.trimmingCharacters(in: .whitespaces), unit: unit, onHand: qty, averageCost: cost))
        }
        try? context.save()
        dismiss()
    }
}

struct PurchaseEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let items: [InventoryItem]
    @State private var selectedID: UUID?
    @State private var quantity = ""
    @State private var unitPrice = ""
    @State private var supplier = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("進貨資料") {
                    Picker("原料", selection: $selectedID) {
                        Text("請選擇").tag(Optional<UUID>.none)
                        ForEach(items) { item in Text(item.name).tag(Optional(item.id)) }
                    }
                    TextField("進貨數量", text: $quantity).keyboardType(.decimalPad)
                    TextField("每單位價格（元）", text: $unitPrice).keyboardType(.decimalPad)
                    TextField("供應商", text: $supplier)
                    TextField("備註", text: $note)
                }
                Text("進貨會增加庫存，並依加權平均法更新原料平均成本。進貨數量與原料庫存單位必須一致。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("新增進貨")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("確認進貨", action: save).disabled(!valid) }
            }
            .onAppear { if selectedID == nil { selectedID = items.first?.id } }
        }
    }

    private var valid: Bool {
        selectedID != nil && (Double(quantity).map { $0 > 0 } ?? false) &&
        (Double(unitPrice).map { $0 > 0 } ?? false)
    }

    private func save() {
        guard let id = selectedID, let item = items.first(where: { $0.id == id }),
              let qty = Double(quantity), qty > 0,
              let price = Double(unitPrice), price > 0 else { return }
        let oldValue = item.onHand * item.averageCost
        let purchaseValue = qty * price
        let newQty = item.onHand + qty
        item.averageCost = newQty > 0 ? (oldValue + purchaseValue) / newQty : price
        item.onHand = newQty
        context.insert(InventoryPurchase(itemName: item.name, unit: item.unit, quantity: qty, unitPrice: price, supplier: supplier, note: note))
        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
        }
    }
}
