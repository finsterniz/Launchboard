//
//  PersistenceManager.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import Foundation
import Combine

/// 持久化数据结构
struct PersistenceData: Codable {
    var apps: [AppItem]
    var groups: [AppGroup]
    var gridLayout: [[String?]]  // 网格布局，存储 app/group ID
    var currentPage: Int
    
    init() {
        self.apps = []
        self.groups = []
        self.gridLayout = Array(repeating: Array(repeating: nil, count: 7), count: 5)
        self.currentPage = 0
    }

    init(apps: [AppItem], groups: [AppGroup], gridLayout: [[String?]], currentPage: Int) {
        self.apps = apps
        self.groups = groups
        self.gridLayout = gridLayout
        self.currentPage = currentPage
    }
}

/// 持久化管理器 - 负责数据的本地存储和读取
class PersistenceManager: ObservableObject {
    
    // MARK: - 常量
    private let fileName = "LaunchBoardData.json"
    private let appSupportDirectory = "LaunchBoard"
    
    // MARK: - 计算属性
    
    /// 应用支持目录路径
    private var appSupportPath: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, 
                                           in: .userDomainMask)
        let appSupportURL = paths[0].appendingPathComponent(appSupportDirectory)
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appSupportURL, 
                                                withIntermediateDirectories: true, 
                                                attributes: nil)
        return appSupportURL
    }
    
    /// 数据文件路径
    private var dataFileURL: URL {
        return appSupportPath.appendingPathComponent(fileName)
    }
    
    // MARK: - 公共方法
    
    /// 保存数据
    func save(_ data: PersistenceData) {
        do {
            let jsonData = try JSONEncoder().encode(data)
            try jsonData.write(to: dataFileURL)
            print("数据保存成功: \(dataFileURL.path)")
        } catch {
            print("保存数据失败: \(error.localizedDescription)")
        }
    }
    
    /// 加载数据
    func load() -> PersistenceData {
        guard FileManager.default.fileExists(atPath: dataFileURL.path) else {
            print("数据文件不存在，返回默认数据")
            return PersistenceData()
        }
        
        do {
            let jsonData = try Data(contentsOf: dataFileURL)
            let data = try JSONDecoder().decode(PersistenceData.self, from: jsonData)
            print("数据加载成功: \(data.apps.count) 个应用, \(data.groups.count) 个分组")
            return data
        } catch {
            print("加载数据失败: \(error.localizedDescription)")
            return PersistenceData()
        }
    }
    
    /// 检查数据文件是否存在
    func dataFileExists() -> Bool {
        return FileManager.default.fileExists(atPath: dataFileURL.path)
    }
    
    /// 删除数据文件 (重置)
    func reset() {
        do {
            if FileManager.default.fileExists(atPath: dataFileURL.path) {
                try FileManager.default.removeItem(at: dataFileURL)
                print("数据文件已删除")
            }
        } catch {
            print("删除数据文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 备份当前数据
    func backup() -> Bool {
        guard dataFileExists() else { return false }
        
        let timestamp = DateFormatter().string(from: Date())
        let backupFileName = "LaunchBoardData_backup_\(timestamp).json"
        let backupURL = appSupportPath.appendingPathComponent(backupFileName)
        
        do {
            try FileManager.default.copyItem(at: dataFileURL, to: backupURL)
            print("数据备份成功: \(backupURL.path)")
            return true
        } catch {
            print("数据备份失败: \(error.localizedDescription)")
            return false
        }
    }
}
