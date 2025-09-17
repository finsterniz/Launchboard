//
//  AppGroup.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import Foundation
import AppKit

/// 应用分组模型
struct AppGroup: Codable, Identifiable, Equatable {
    let id = UUID()
    var name: String                    // 分组名称
    var apps: [AppItem]                 // 分组内的应用
    var position: GridPosition?         // 网格位置
    
    // MARK: - Codable 支持
    enum CodingKeys: String, CodingKey {
        case id, name, apps, position
    }
    
    // MARK: - Equatable 支持
    static func == (lhs: AppGroup, rhs: AppGroup) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - 便利方法
    
    /// 获取分组图标 (使用第一个应用的图标，或者组合图标)
    var icon: NSImage? {
        guard !apps.isEmpty else { return nil }
        
        // 简单实现：返回第一个应用的图标
        // TODO: 后续可以实现组合图标效果
        return apps.first?.icon
    }
    
    /// 添加应用到分组
    mutating func addApp(_ app: AppItem) {
        // 检查应用是否已存在
        if !apps.contains(where: { $0.id == app.id }) {
            apps.append(app)
        }
    }
    
    /// 从分组移除应用
    mutating func removeApp(_ app: AppItem) {
        apps.removeAll { $0.id == app.id }
    }
    
    /// 检查分组是否为空
    var isEmpty: Bool {
        return apps.isEmpty
    }
    
    /// 获取分组内有效的应用 (过滤掉不存在的应用)
    var validApps: [AppItem] {
        return apps.filter { $0.exists }
    }
}
