//
//  AppScannerService.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import Foundation
import AppKit
import Combine

/// 应用扫描服务 - 负责扫描系统中的应用程序
class AppScannerService: ObservableObject {
    
    // MARK: - 扫描路径
    private let scanPaths = [
        "/Applications",                    // 系统应用目录
        NSHomeDirectory() + "/Applications" // 用户应用目录
    ]
    
    // MARK: - 公共方法
    
    /// 扫描所有应用程序
    /// - Returns: 扫描到的应用列表
    func scanApplications() async -> [AppItem] {
        var allApps: [AppItem] = []
        
        for path in scanPaths {
            let apps = await scanDirectory(path)
            allApps.append(contentsOf: apps)
        }
        
        // 去重 (基于 bundle identifier)
        let uniqueApps = removeDuplicates(from: allApps)
        
        print("扫描完成，共找到 \(uniqueApps.count) 个应用")
        return uniqueApps
    }
    
    // MARK: - 私有方法
    
    /// 扫描指定目录
    private func scanDirectory(_ directoryPath: String) async -> [AppItem] {
        let fileManager = FileManager.default
        var apps: [AppItem] = []
        
        guard fileManager.fileExists(atPath: directoryPath) else {
            print("目录不存在: \(directoryPath)")
            return apps
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directoryPath)
            
            for item in contents {
                let itemPath = directoryPath + "/" + item
                
                // 检查是否为 .app 文件
                if item.hasSuffix(".app") {
                    if let appItem = createAppItem(from: itemPath) {
                        apps.append(appItem)
                    }
                }
            }
        } catch {
            print("扫描目录失败 \(directoryPath): \(error.localizedDescription)")
        }
        
        return apps
    }
    
    /// 从应用路径创建 AppItem
    private func createAppItem(from appPath: String) -> AppItem? {
        guard let bundle = Bundle(path: appPath) else {
            print("无法创建 Bundle: \(appPath)")
            return nil
        }
        
        // 获取应用信息
        let bundleIdentifier = bundle.bundleIdentifier ?? "unknown"
        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
                  bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                  URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
        
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? name

        return AppItem(
            name: name,
            displayName: displayName,
            bundleIdentifier: bundleIdentifier,
            path: appPath,
            iconPath: nil, // 不再预先提取图标路径，让 AppItem.icon 动态获取
            position: nil
        )
    }

    
    /// 去除重复的应用 (基于 bundle identifier)
    private func removeDuplicates(from apps: [AppItem]) -> [AppItem] {
        var seen = Set<String>()
        var uniqueApps: [AppItem] = []
        
        for app in apps {
            if !seen.contains(app.bundleIdentifier) {
                seen.insert(app.bundleIdentifier)
                uniqueApps.append(app)
            }
        }
        
        return uniqueApps
    }
}
