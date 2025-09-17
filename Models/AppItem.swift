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
    let id: UUID
    let name: String                    // 应用名称
    let displayName: String             // 显示名称
    let bundleIdentifier: String        // Bundle ID
    let path: String                    // .app 文件路径
    let iconPath: String?               // 图标路径
    var position: GridPosition?         // 网格位置
    
    init(id: UUID = UUID(),
         name: String,
         displayName: String,
         bundleIdentifier: String,
         path: String,
         iconPath: String?,
         position: GridPosition?) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.iconPath = iconPath
        self.position = position
    }
    
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
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 64, height: 64)
        return icon
    }
    
    /// 启动应用（使用较新的 API）
    func launch() -> Bool {
        let url = URL(fileURLWithPath: path)
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
            if let error = error {
                print("启动应用失败: \(error.localizedDescription)")
            }
        }
        // 这里为简化，调用后即返回 true；若需严格成功与否，可改为 async/await 风格并等待回调。
        return true
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
