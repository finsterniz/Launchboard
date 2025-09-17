//
//  AppItem.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import Foundation
import AppKit
import UniformTypeIdentifiers
import CoreTransferable

/// 应用程序信息模型
struct AppItem: Codable, Identifiable, Equatable, Transferable {
    let id = UUID()
    let name: String                    // 应用名称
    let displayName: String             // 显示名称
    let bundleIdentifier: String        // Bundle ID
    let path: String                    // .app 文件路径
    let iconPath: String?               // 图标路径
    var position: GridPosition?         // 网格位置
    
    // MARK: - Codable 支持
    enum CodingKeys: String, CodingKey {
        case id, name, displayName, bundleIdentifier, path, iconPath, position
    }
    
    // MARK: - Equatable 支持
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - 便利方法
    
    /// 获取应用图标
    var icon: NSImage? {
        // 直接使用系统提供的图标获取方法，这是最可靠的方式
        let icon = NSWorkspace.shared.icon(forFile: path)
        // 设置合适的图标大小
        icon.size = NSSize(width: 64, height: 64)
        return icon
    }
    
    /// 启动应用
    func launch() -> Bool {
        let url = URL(fileURLWithPath: path)
        do {
            try NSWorkspace.shared.launchApplication(at: url, 
                                                   options: [], 
                                                   configuration: [:])
            return true
        } catch {
            print("启动应用失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 检查应用是否仍然存在
    var exists: Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    // MARK: - Transferable 协议实现
    // 使用系统内建的 JSON 类型进行编码传输，避免自定义 UTI
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

