import SwiftUI

/// 分组展开视图（类似 iPad 文件夹弹出）
/// - 使用 matchedGeometryEffect 与网格中的分组格子进行几何匹配
/// - 居中面板 + 半透明背景，Tab 分页展示分组内应用
struct AppGroupOverlayView: View {
    let group: AppGroup
    let namespace: Namespace.ID
    let onClose: () -> Void
    let onAppTap: (AppItem) -> Void
    
    // 分组内分页配置（可按窗口尺寸自适应）
    private let columnsPerPage = 6
    private let rowsPerPage = 4
    private var itemsPerPage: Int { columnsPerPage * rowsPerPage }
    
    @State private var currentPage: Int = 0
    
    private var pages: [[AppItem]] {
        group.validApps.chunked(into: itemsPerPage)
    }
    
    var body: some View {
        ZStack {
            // 半透明暗色背景，点击关闭
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
                .transition(.opacity)
            
            // 使用 matchedGeometryEffect 的容器（与网格中的占位同 id）
            VStack(spacing: 12) {
                // 标题栏
                HStack {
                    Text(group.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Button("完成") { onClose() }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.secondary.opacity(0.15))
                        )
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // 分页网格
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { pageIndex in
                        let pageApps = pages[pageIndex]
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnsPerPage),
                            spacing: 16
                        ) {
                            ForEach(pageApps, id: \.id) { app in
                                VStack(spacing: 6) {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 56, height: 56)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(.quaternary)
                                            .frame(width: 56, height: 56)
                                            .overlay {
                                                Image(systemName: "app")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.secondary)
                                            }
                                    }
                                    Text(app.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 72)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onAppTap(app)
                                }
                            }
                        }
                        .padding(20)
                        .tag(pageIndex)
                    }
                }
                .frame(width: 600, height: 360)
                
                Spacer(minLength: 8)
            }
            .frame(width: 640, height: 460)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 20)
            .matchedGeometryEffect(id: group.id, in: namespace) // 关键：与格子匹配
        }
        .onAppear {
            currentPage = 0
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
