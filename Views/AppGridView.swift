//
//  AppGridView.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import SwiftUI

/// 拖拽落点动作
enum DropAction: Equatable {
    case insertBefore(indexInPage: Int)     // 在目标单元格之前插入（挤右边）
    case insertAtEmpty(indexInPage: Int)    // 插入到空白占位
    case groupWith(targetIndexInPage: Int)  // 与目标单元格分组（若目标是 group 则加入该 group）
}

/// 应用网格视图 - 7x5 网格布局显示应用、分组，支持拖拽重排和自动翻页
struct AppGridView: View {
    let cells: [GridCell]                  // 改为混合数据源
    let onAppTap: (AppItem) -> Void
    let onDragStarted: ((AppItem) -> Void)?
    let onDragEnded: (() -> Void)?
    // 兼容旧回调（插入）
    let onAppMoved: ((AppItem, Int) -> Void)?
    // 新的动作回调
    let onDropAction: ((AppItem, DropAction) -> Void)?
    let onPageChange: ((Int) -> Void)?  // 页面切换回调
    let currentPage: Int                // 当前页面
    let totalPages: Int                 // 总页数

    @State private var draggedApp: AppItem?
    @State private var targetIndex: Int?
    @State private var autoScrollTimer: Timer?  // 自动翻页定时器
    @State private var dragLocation: CGPoint = .zero  // 拖拽位置
    @State private var containerSize: CGSize = .zero  // 容器大小

    init(
        cells: [GridCell],
        onAppTap: @escaping (AppItem) -> Void,
        onDragStarted: ((AppItem) -> Void)? = nil,
        onDragEnded: (() -> Void)? = nil,
        onAppMoved: ((AppItem, Int) -> Void)? = nil,
        onDropAction: ((AppItem, DropAction) -> Void)? = nil,
        onPageChange: ((Int) -> Void)? = nil,
        currentPage: Int = 0,
        totalPages: Int = 1
    ) {
        self.cells = cells
        self.onAppTap = onAppTap
        self.onDragStarted = onDragStarted
        self.onDragEnded = onDragEnded
        self.onAppMoved = onAppMoved
        self.onDropAction = onDropAction
        self.onPageChange = onPageChange
        self.currentPage = currentPage
        self.totalPages = totalPages
    }
    
    // 7x5 网格配置
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 7)
    private let maxItems = 35 // 7 * 5
    
    var body: some View {
        GeometryReader { geometry in
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(0..<maxItems, id: \.self) { index in
                    gridCellView(for: index, geometry: geometry)
                }
            }
            .padding()
            .simultaneousGesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        dragLocation = value.location
                        if draggedApp != nil {
                            checkEdgeScrolling(at: dragLocation, in: geometry.size)
                        }
                    }
                    .onEnded { _ in
                        stopAutoScroll()
                    }
            )
            .onChange(of: draggedApp) { _ in
                containerSize = geometry.size
            }
        }
        .onDisappear {
            stopAutoScroll()
        }
    }
    
    @ViewBuilder
    private func gridCellView(for index: Int, geometry: GeometryProxy) -> some View {
        let cell = index < cells.count ? cells[index] : .empty
        
        switch cell {
        case .app(let app):
            AppIconView(
                app: app,
                onTap: { onAppTap(app) },
                onDragStarted: { dragged in
                    draggedApp = dragged
                    onDragStarted?(dragged)
                },
                onDragEnded: {
                    stopAutoScroll()
                    draggedApp = nil
                    targetIndex = nil
                    onDragEnded?()
                }
            )
            .dropDestination(for: AppItem.self) { droppedApps, location in
                guard let droppedApp = droppedApps.first else { return false }
                // 避免对自己进行分组或插入前的无意义操作
                if droppedApp.id == app.id { return false }
                
                stopAutoScroll()
                
                let action = dropAction(for: location, isEmptySlot: false, indexInPage: index, targetViewSize: CGSize(width: 80, height: 96))
                if let onDropAction {
                    onDropAction(droppedApp, action)
                } else {
                    // 兼容旧回调：仅在 insertBefore/insertAtEmpty 时回退
                    switch action {
                    case .insertBefore(let idx), .insertAtEmpty(let idx):
                        onAppMoved?(droppedApp, idx)
                    case .groupWith:
                        break
                    }
                }
                return true
            } isTargeted: { isTargeted in
                if isTargeted {
                    targetIndex = index
                    checkEdgeScrolling(at: dragLocation, in: geometry.size)
                } else {
                    targetIndex = nil
                    stopAutoScroll()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(targetIndex == index ? Color.accentColor.opacity(0.3) : Color.clear)
                    .animation(.easeInOut(duration: 0.2), value: targetIndex)
            )
            
        case .group:
            // 分组占位（圆角矩形）
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                )
                .dropDestination(for: AppItem.self) { droppedApps, location in
                    guard let droppedApp = droppedApps.first else { return false }
                    stopAutoScroll()
                    
                    // 在 group 占位上：左侧仍视为“插入前”，中/右侧视为“加入该 group”
                    let action = dropAction(for: location, isEmptySlot: false, indexInPage: index, targetViewSize: CGSize(width: 64, height: 64))
                    if let onDropAction {
                        onDropAction(droppedApp, action)
                    } else {
                        switch action {
                        case .insertBefore(let idx), .insertAtEmpty(let idx):
                            onAppMoved?(droppedApp, idx)
                        case .groupWith:
                            break
                        }
                    }
                    return true
                } isTargeted: { isTargeted in
                    if isTargeted {
                        targetIndex = index
                        checkEdgeScrolling(at: dragLocation, in: geometry.size)
                    } else {
                        targetIndex = nil
                        stopAutoScroll()
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(targetIndex == index ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 2)
                        .animation(.easeInOut(duration: 0.2), value: targetIndex)
                )
            
        case .empty:
            // 空白占位
            Rectangle()
                .fill(Color.clear)
                .frame(width: 64, height: 64)
                .dropDestination(for: AppItem.self) { droppedApps, location in
                    guard let droppedApp = droppedApps.first else { return false }
                    stopAutoScroll()
                    
                    let action = dropAction(for: location, isEmptySlot: true, indexInPage: index, targetViewSize: CGSize(width: 64, height: 64))
                    if let onDropAction {
                        onDropAction(droppedApp, action)
                    } else {
                        switch action {
                        case .insertBefore(let idx), .insertAtEmpty(let idx):
                            onAppMoved?(droppedApp, idx)
                        case .groupWith:
                            break
                        }
                    }
                    return true
                } isTargeted: { isTargeted in
                    if isTargeted {
                        targetIndex = index
                        checkEdgeScrolling(at: dragLocation, in: geometry.size)
                    } else {
                        targetIndex = nil
                        stopAutoScroll()
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(targetIndex == index ? Color.accentColor.opacity(0.3) : Color.clear)
                        .animation(.easeInOut(duration: 0.2), value: targetIndex)
                )
        }
    }
    
    /// 根据落点位置推断拖拽动作
    private func dropAction(for location: CGPoint, isEmptySlot: Bool, indexInPage: Int, targetViewSize: CGSize) -> DropAction {
        if isEmptySlot {
            return .insertAtEmpty(indexInPage: indexInPage)
        }
        // 以目标视图宽度的 0.35 作为“左侧插入”阈值，中间/右侧视为覆盖分组/加入分组
        let leftThreshold = targetViewSize.width * 0.35
        if location.x <= leftThreshold {
            return .insertBefore(indexInPage: indexInPage)
        } else {
            return .groupWith(targetIndexInPage: indexInPage)
        }
    }

    // MARK: - 边缘检测和自动翻页
    private func checkEdgeScrolling(at location: CGPoint, in size: CGSize) {
        let edgeThreshold: CGFloat = 50
        if location.x < edgeThreshold && currentPage > 0 {
            startAutoScroll(direction: .previous)
        } else if location.x > size.width - edgeThreshold && currentPage < totalPages - 1 {
            startAutoScroll(direction: .next)
        } else {
            stopAutoScroll()
        }
    }

    private enum ScrollDirection { case previous, next }

    private func startAutoScroll(direction: ScrollDirection) {
        stopAutoScroll()
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in
            let targetPage = direction == .previous ? max(0, currentPage - 1) : min(totalPages - 1, currentPage + 1)
            if targetPage != currentPage {
                onPageChange?(targetPage)
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
}

#Preview {
    // 简单的占位预览
    AppGridView(
        cells: Array(repeating: .empty, count: 35),
        onAppTap: { _ in },
        currentPage: 0,
        totalPages: 1
    )
    .frame(width: 600, height: 400)
    .background(.regularMaterial)
}

