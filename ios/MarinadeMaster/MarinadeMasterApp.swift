import SwiftUI

@main
struct MarinadeMasterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("醃製配方管理師")
                        .font(.largeTitle.bold())
                    Text("配方研發・生產批次・原料成本")
                        .foregroundStyle(.secondary)
                    ContentUnavailableView(
                        "尚未連接雲端資料",
                        systemImage: "cloud",
                        description: Text("此為 iOS 原生 App 起始畫面。待雲端 API 與資料模型完成後接入正式資料。")
                    )
                }
                .padding()
                .navigationTitle("總覽")
            }
            .tabItem { Label("總覽", systemImage: "house") }

            NavigationStack {
                ContentUnavailableView("配方中心", systemImage: "book.closed",
                    description: Text("將接入版本鎖定、原始配方及重量換算。"))
                    .navigationTitle("配方")
            }
            .tabItem { Label("配方", systemImage: "list.bullet.rectangle") }

            NavigationStack {
                ContentUnavailableView("生產批次", systemImage: "clipboard",
                    description: Text("將接入批次紀錄、照片與庫存扣料。"))
                    .navigationTitle("生產")
            }
            .tabItem { Label("生產", systemImage: "shippingbox") }
        }
    }
}
