//
//  LaunchBoardViewModel.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import Foundation
import SwiftUI
import Combine

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
    
    /// 当前页面的应用
    var currentPageApps: [AppItem] {
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, filteredApps.count)
        
        guard startIndex < filteredApps.count else { return [] }
        return Array(filteredApps[startIndex..<endIndex])
    }
    
    /// 总页数
    var totalPages: Int {
        return max(1, (filteredApps.count + itemsPerPage - 1) / itemsPerPage)
    }
    
    /// 是否可以向前翻页
    var canGoToPreviousPage: Bool {
        return currentPage > 0
    }
    
    /// 是否可以向后翻页
    var canGoToNextPage: Bool {
        return currentPage < totalPages - 1
    }
    
    // MARK: - 初始化
    
    init() {
        loadData()
    }
    
    // MARK: - 公共方法
    
    /// 初始化加载数据
    func loadData() {
        isLoading = true
        
        Task {
            // 先尝试从本地加载
            let persistedData = persistenceManager.load()
            
            if !persistedData.apps.isEmpty {
                // 使用本地数据
                self.apps = persistedData.apps.filter { $0.exists } // 过滤掉不存在的应用
                self.groups = persistedData.groups
                self.gridLayout = persistedData.gridLayout
                self.currentPage = persistedData.currentPage
                print("从本地加载了 \(self.apps.count) 个应用")
            } else {
                // 首次运行，扫描应用
                await scanApplications()
            }
            
            self.isLoading = false
        }
    }
    
    /// 扫描应用程序
    func scanApplications() async {
        isLoading = true
        
        let scannedApps = await appScanner.scanApplications()
        self.apps = scannedApps
        
        // 自动排列到网格中
        arrangeAppsInGrid()
        
        // 保存数据
        saveData()
        
        isLoading = false
    }
    
    /// 启动应用
    func launchApp(_ app: AppItem) {
        let success = app.launch()
        if success {
            print("启动应用: \(app.displayName)")
        } else {
            print("启动应用失败: \(app.displayName)")
        }
    }
    
    /// 搜索应用 (启动第一个匹配的应用)
    func launchFirstSearchResult() {
        guard !searchText.isEmpty,
              let firstApp = filteredApps.first else { return }
        
        launchApp(firstApp)
        clearSearch()
    }
    
    /// 清除搜索
    func clearSearch() {
        searchText = ""
    }
    
    /// 翻页
    func goToNextPage() {
        if canGoToNextPage {
            currentPage += 1
            saveData()
        }
    }
    
    func goToPreviousPage() {
        if canGoToPreviousPage {
            currentPage -= 1
            saveData()
        }
    }
    
    /// 跳转到指定页面
    func goToPage(_ page: Int) {
        let targetPage = max(0, min(page, totalPages - 1))
        if targetPage != currentPage {
            currentPage = targetPage
            saveData()
        }
    }
    
    // MARK: - 私有方法
    
    /// 自动排列应用到网格中
    private func arrangeAppsInGrid() {
        // 重置网格布局
        gridLayout = Array(repeating: Array(repeating: nil, count: 7), count: 5)
        
        // 简单的线性排列
        for (index, app) in apps.enumerated() {
            let page = index / itemsPerPage
            let positionInPage = index % itemsPerPage
            let row = positionInPage / 7
            let column = positionInPage % 7
            
            // 更新应用位置
            apps[index].position = GridPosition(row: row, column: column, page: page)
            
            // 如果是第一页，更新网格布局
            if page == 0 && row < 5 && column < 7 {
                gridLayout[row][column] = app.id.uuidString
            }
        }
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
