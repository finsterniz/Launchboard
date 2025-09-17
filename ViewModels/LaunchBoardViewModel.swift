//
//  LaunchBoardViewModel.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import Foundation
import SwiftUI
import Combine

/// 网格单元：可以是 App、分组或空
enum GridCell: Equatable {
    case app(AppItem)
    case group(AppGroup)
    case empty
}

/// 主视图模型 - 管理应用列表、搜索、分页等业务逻辑
@MainActor
class LaunchBoardViewModel: ObservableObject {
    
    // MARK: - Published 属性
    @Published var apps: [AppItem] = []
    @Published var groups: [AppGroup] = []
    @Published var searchText: String = ""
    @Published var currentPage: Int = 0
    @Published var isLoading: Bool = false
    @Published var gridLayout: [[String?]] = Array(repeating: Array(repeating: nil, count: 7), count: 5)
    
    // MARK: - 服务
    private let appScanner = AppScannerService()
    private let persistenceManager = PersistenceManager()
    
    // MARK: - 常量
    private let itemsPerPage = 35  // 7x5 网格
    
    // MARK: - 计算属性
    
    /// 过滤后的应用列表 (基于搜索文本)
    var filteredApps: [AppItem] {
        if searchText.isEmpty {
            return apps
        } else {
            return apps.filter { app in
                app.displayName.localizedCaseInsensitiveContains(searchText) ||
                app.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    /// 当前页面的“混合”网格单元（App + Group + Empty），长度固定为 35
    var currentPageCells: [GridCell] {
        var cells = Array(repeating: GridCell.empty, count: itemsPerPage)
        
        // 1) 先把本页的分组放到它们的位置
        for group in groups {
            guard let pos = group.position, pos.page == currentPage, pos.isValid else { continue }
            let idx = pos.linearIndex
            if idx >= 0 && idx < itemsPerPage {
                cells[idx] = .group(group)
            }
        }
        
        // 2) 计算本页可放置的 app 个数（剩余空位）
        let groupCountOnPage = cells.filter {
            if case .group = $0 { return true }
            return false
        }.count
        let appSlotsOnPage = itemsPerPage - groupCountOnPage
        
        // 3) 计算本页 apps 的全局起始索引（考虑前面页面的 group 占位）
        let startIndex = appStartIndexForPage(currentPage)
        let endIndex = min(startIndex + appSlotsOnPage, filteredApps.count)
        let pageApps = (startIndex < endIndex) ? Array(filteredApps[startIndex..<endIndex]) : []
        
        // 4) 按从左到右填充空位
        var appIterator = pageApps.makeIterator()
        for i in 0..<itemsPerPage {
            if case .empty = cells[i], let next = appIterator.next() {
                cells[i] = .app(next)
            }
        }
        return cells
    }
    
    /// 总页数（考虑 group 占位后的“每页 app 容量”）
    var totalPages: Int {
        var remainingApps = filteredApps.count
        var page = 0
        while remainingApps > 0 || page == 0 {
            let capacity = itemsPerPage - groupsCount(onPage: page)
            remainingApps = max(0, remainingApps - max(0, capacity))
            if remainingApps <= 0 { break }
            page += 1
        }
        return max(1, page + 1)
    }
    
    /// 是否可以向前翻页
    var canGoToPreviousPage: Bool { currentPage > 0 }
    
    /// 是否可以向后翻页
    var canGoToNextPage: Bool { currentPage < totalPages - 1 }
    
    // MARK: - 初始化
    
    init() {
        loadData()
    }
    
    // MARK: - 公共方法
    
    func loadData() {
        isLoading = true
        Task {
            let persistedData = persistenceManager.load()
            if !persistedData.apps.isEmpty {
                self.apps = persistedData.apps.filter { $0.exists }
                self.groups = persistedData.groups
                self.gridLayout = persistedData.gridLayout
                self.currentPage = persistedData.currentPage
                print("从本地加载了 \(self.apps.count) 个应用")
            } else {
                await scanApplications()
            }
            self.isLoading = false
        }
    }
    
    func scanApplications() async {
        isLoading = true
        let scannedApps = await appScanner.scanApplications()
        self.apps = scannedApps
        arrangeAppsInGrid()
        saveData()
        isLoading = false
    }
    
    func launchApp(_ app: AppItem) {
        let success = app.launch()
        print(success ? "启动应用: \(app.displayName)" : "启动应用失败: \(app.displayName)")
    }
    
    func launchFirstSearchResult() {
        guard !searchText.isEmpty, let firstApp = filteredApps.first else { return }
        launchApp(firstApp)
        clearSearch()
    }
    
    func clearSearch() { searchText = "" }
    
    func goToNextPage() { if canGoToNextPage { currentPage += 1; saveData() } }
    func goToPreviousPage() { if canGoToPreviousPage { currentPage -= 1; saveData() } }
    func goToPage(_ page: Int) {
        let targetPage = max(0, min(page, totalPages - 1))
        if targetPage != currentPage { currentPage = targetPage; saveData() }
    }

    // 兼容旧接口：移动应用到指定位置（在当前页内）
    func moveApp(_ app: AppItem, to targetIndexInPage: Int) {
        guard searchText.isEmpty else {
            print("搜索模式下不允许移动应用")
            return
        }
        guard let globalCurrentIndex = indexOfAppMatching(app) else {
            print("未找到要移动的应用: \(app.displayName)")
            return
        }
        let globalTargetIndex = appInsertionGlobalIndex(for: targetIndexInPage, onPage: currentPage)
        insertApp(fromGlobalIndex: globalCurrentIndex, toGlobalIndex: globalTargetIndex)
    }
    
    /// 新接口：处理拖拽落点动作
    func handleDrop(_ app: AppItem, action: DropAction) {
        guard searchText.isEmpty else {
            print("搜索模式下不允许移动/分组")
            return
        }
        guard let globalSourceIndex = indexOfAppMatching(app) else {
            print("未找到要移动的应用: \(app.displayName)")
            return
        }
        
        switch action {
        case .insertBefore(let indexInPage), .insertAtEmpty(let indexInPage):
            let globalTargetIndex = appInsertionGlobalIndex(for: indexInPage, onPage: currentPage)
            insertApp(fromGlobalIndex: globalSourceIndex, toGlobalIndex: globalTargetIndex)
            
        case .groupWith(let targetIndexInPage):
            if let existingGroupIndex = groupIndexAt(page: currentPage, indexInPage: targetIndexInPage) {
                // 目标格已有 group：把 app 加入该分组
                let appItem = apps[globalSourceIndex]
                groups[existingGroupIndex].addApp(appItem)
                apps.remove(at: globalSourceIndex)
                arrangeAppsInGrid()
                saveData()
                print("已将 \(appItem.displayName) 加入分组: \(groups[existingGroupIndex].name)")
            } else {
                // 目标格是 app 或空：创建新分组并放置在该格
                let pos = GridPosition.from(linearIndex: targetIndexInPage, page: currentPage)
                groupApp(fromGlobalIndex: globalSourceIndex, atGridPosition: pos)
            }
        }
    }
    
    // MARK: - 私有方法（查找/移动/分组/映射/保存）
    
    private func groupsCount(onPage page: Int) -> Int {
        groups.filter { $0.position?.page == page }.count
    }
    
    /// 前面各页累计的 app 起始索引（每页容量 = 35 - 该页 group 数）
    private func appStartIndexForPage(_ page: Int) -> Int {
        var start = 0
        if page > 0 {
            for p in 0..<(page) {
                start += max(0, itemsPerPage - groupsCount(onPage: p))
            }
        }
        return min(start, filteredApps.count)
    }
    
    /// 计算“插入到本页 indexInPage 位置之前”对应的全局 apps 插入索引
    private func appInsertionGlobalIndex(for indexInPage: Int, onPage page: Int) -> Int {
        let startIndex = appStartIndexForPage(page)
        // 统计 indexInPage 之前的“app 可放置槽位”数量（即非 group 的格子）
        let cells = currentPageCells
        let appSlotsBefore = (0..<min(indexInPage, cells.count)).reduce(0) { count, i in
            if case .group = cells[i] { return count } else { return count + 1 }
        }
        return min(startIndex + appSlotsBefore, apps.count)
    }
    
    /// 在 apps 中查找与拖拽来的 app 对应的全局索引
    private func indexOfAppMatching(_ dragged: AppItem) -> Int? {
        if let idx = apps.firstIndex(where: { $0.id == dragged.id }) { return idx }
        if let idx = apps.firstIndex(where: { $0.bundleIdentifier == dragged.bundleIdentifier && $0.path == dragged.path }) { return idx }
        if let idx = apps.firstIndex(where: { $0.bundleIdentifier == dragged.bundleIdentifier }) { return idx }
        return nil
    }
    
    /// 当前页、指定格子是否有 group（返回其在 groups 数组中的索引）
    private func groupIndexAt(page: Int, indexInPage: Int) -> Int? {
        let pos = GridPosition.from(linearIndex: indexInPage, page: page)
        return groups.firstIndex(where: { $0.position == pos })
    }
    
    /// 把 apps[source] 移动到 target（插入）
    private func insertApp(fromGlobalIndex source: Int, toGlobalIndex target: Int) {
        let clampedTarget = max(0, min(target, apps.count - 1))
        if source == clampedTarget { return }
        let item = apps.remove(at: source)
        let adjustedTarget = source < clampedTarget ? clampedTarget - 1 : clampedTarget
        apps.insert(item, at: adjustedTarget)
        arrangeAppsInGrid()
        saveData()
        print("移动应用 \(item.displayName) 到全局索引 \(adjustedTarget)")
    }
    
    /// 将 source 索引的 app 与目标网格位置分组成一个新分组，并把分组放在该位置
    private func groupApp(fromGlobalIndex source: Int, atGridPosition position: GridPosition) {
        guard source < apps.count else { return }
        // 目标格如果已有 app，需要先找到该 app 的全局索引
        let targetLinearIndex = position.linearIndex
        let targetCell = currentPageCells.indices.contains(targetLinearIndex) ? currentPageCells[targetLinearIndex] : .empty
        
        let sourceApp = apps[source]
        var appsToGroup: [AppItem] = [sourceApp]
        
        switch targetCell {
        case .app(let targetApp):
            if let targetIdx = indexOfAppMatching(targetApp) {
                appsToGroup.append(apps[targetIdx])
                // 先移除较大索引，避免错位
                let firstRemove = max(source, targetIdx)
                let secondRemove = min(source, targetIdx)
                apps.remove(at: firstRemove)
                apps.remove(at: secondRemove)
            } else {
                // 找不到目标 app，就只把源 app 分组（占位）
                apps.remove(at: source)
            }
        case .group:
            // 已有 group 的情况在 handleDrop 中处理，这里不走
            return
        case .empty:
            // 只把源 app 分组（占位）
            apps.remove(at: source)
        }
        
        // 创建分组并设置位置为目标格
        var newGroup = AppGroup(name: appsToGroup.first?.displayName ?? "分组", apps: [], position: position)
        appsToGroup.forEach { newGroup.addApp($0) }
        groups.append(newGroup)
        
        arrangeAppsInGrid()
        saveData()
        print("已创建分组: \(newGroup.name)，包含 \(newGroup.apps.map { $0.displayName }.joined(separator: ", "))，位置 page \(position.page) idx \(position.linearIndex)")
    }
    
    /// 自动排列应用到网格中（应用仍线性排列；分组占位不参与此处计算）
    private func arrangeAppsInGrid() {
        // 保持历史逻辑：为 apps 计算 position（不考虑分组，仅线性）
        gridLayout = Array(repeating: Array(repeating: nil, count: 7), count: 5)
        for (index, app) in apps.enumerated() {
            let page = index / itemsPerPage
            let positionInPage = index % itemsPerPage
            let row = positionInPage / 7
            let column = positionInPage % 7
            apps[index].position = GridPosition(row: row, column: column, page: page)
            if page == 0 && row < 5 && column < 7 {
                gridLayout[row][column] = app.id.uuidString
            }
        }
        // 分组的位置不在这里更新，由 group.position 直接控制
    }
    
    /// 保存数据
    private func saveData() {
        let data = PersistenceData(
            apps: apps,
            groups: groups,
            gridLayout: gridLayout,
            currentPage: currentPage
        )
        persistenceManager.save(data)
    }
}

