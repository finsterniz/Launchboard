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
        // 使用 NSWorkspace 获取所有已注册的应用程序
        let workspaceApps = await scanApplicationsUsingWorkspace()

        // 如果 NSWorkspace 方法失败，回退到目录扫描
        if workspaceApps.isEmpty {
            print("NSWorkspace 扫描失败，回退到目录扫描")
            return await scanApplicationsUsingDirectories()
        }

        print("使用 NSWorkspace 扫描完成，共找到 \(workspaceApps.count) 个应用")
        return workspaceApps
    }

    /// 使用 NSWorkspace 扫描所有应用程序（新方法）
    private func scanApplicationsUsingWorkspace() async -> [AppItem] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var apps: [AppItem] = []

                // 使用 NSWorkspace 获取所有应用程序
                if let applicationURLs = self.getAllApplicationURLs() {
                    print("找到 \(applicationURLs.count) 个应用程序")

                    for appURL in applicationURLs {
                        if let appItem = self.createAppItem(from: appURL.path) {
                            apps.append(appItem)
                        }
                    }
                } else {
                    print("NSWorkspace 扫描失败，尝试备用方法")
                    // 备用方法：扫描常见目录
                    apps = []
                }

                // 去重 (基于 bundle identifier)
                let uniqueApps = self.removeDuplicates(from: apps)
                continuation.resume(returning: uniqueApps)
            }
        }
    }

    /// 获取所有应用程序 URL
    private func getAllApplicationURLs() -> [URL]? {
        // 使用 NSWorkspace 的 URL 枚举方法
        let workspace = NSWorkspace.shared
        var applicationURLs: [URL] = []

        // 扫描多个应用目录
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/Applications/Utilities",
            NSHomeDirectory() + "/Applications"
        ]

        for searchPath in searchPaths {
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: [.isDirectoryKey, .isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                // 检查是否为应用程序
                if url.pathExtension == "app" {
                    do {
                        let resourceValues = try url.resourceValues(forKeys: [.isApplicationKey])
                        if resourceValues.isApplication == true {
                            applicationURLs.append(url)
                        }
                    } catch {
                        // 如果无法获取资源值，但是以 .app 结尾，也添加进去
                        if url.path.hasSuffix(".app") {
                            applicationURLs.append(url)
                        }
                    }
                }
            }
        }

        return applicationURLs.isEmpty ? nil : applicationURLs
    }

    /// 使用目录扫描的原始方法（备用）
    private func scanApplicationsUsingDirectories() async -> [AppItem] {
        var allApps: [AppItem] = []

        // 扩展扫描路径，包含更多系统目录
        let expandedScanPaths = [
            "/Applications",                    // 用户应用目录
            "/System/Applications",             // 系统应用目录（macOS 10.15+）
            "/Applications/Utilities",          // 系统工具
            NSHomeDirectory() + "/Applications" // 用户应用目录
        ]

        for path in expandedScanPaths {
            let apps = await scanDirectory(path)
            allApps.append(contentsOf: apps)
        }

        // 去重 (基于 bundle identifier)
        let uniqueApps = removeDuplicates(from: allApps)

        print("目录扫描完成，共找到 \(uniqueApps.count) 个应用")
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
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: appPath) else {
            print("应用不存在: \(appPath)")
            return nil
        }

        // 检查是否为 .app 文件
        guard appPath.hasSuffix(".app") else {
            print("不是 .app 文件: \(appPath)")
            return nil
        }

        // 尝试创建 Bundle
        guard let bundle = Bundle(path: appPath) else {
            print("无法创建 Bundle: \(appPath)")
            // 使用备用方法创建 AppItem
            return createAppItemFallback(from: appPath)
        }

        // 检查是否有有效的 Bundle Identifier
        let bundleIdentifier = bundle.bundleIdentifier ?? "unknown.\(UUID().uuidString)"

        // 获取应用名称，尝试多个键值
        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
                  bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                  bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String ??
                  URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent

        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? name

        // 过滤掉一些不需要显示的应用
        if shouldSkipApplication(name: name, bundleId: bundleIdentifier, path: appPath) {
            return nil
        }

        return AppItem(
            name: name,
            displayName: displayName,
            bundleIdentifier: bundleIdentifier,
            path: appPath,
            iconPath: nil, // 不再预先提取图标路径，让 AppItem.icon 动态获取
            position: nil
        )
    }

    /// 备用方法：当无法创建 Bundle 时使用
    private func createAppItemFallback(from appPath: String) -> AppItem? {
        let url = URL(fileURLWithPath: appPath)
        let name = url.deletingPathExtension().lastPathComponent

        // 简单的名称清理
        let cleanName = name.replacingOccurrences(of: "_", with: " ")
                           .replacingOccurrences(of: "-", with: " ")

        return AppItem(
            name: cleanName,
            displayName: cleanName,
            bundleIdentifier: "fallback.\(name.lowercased())",
            path: appPath,
            iconPath: nil,
            position: nil
        )
    }

    /// 判断是否应该跳过某个应用
    private func shouldSkipApplication(name: String, bundleId: String, path: String) -> Bool {
        // 跳过系统内部组件
        let skipPatterns = [
            "com.apple.loginwindow",
            "com.apple.dock",
            "com.apple.finder",
            "com.apple.systemuiserver"
        ]

        for pattern in skipPatterns {
            if bundleId.lowercased().contains(pattern) {
                return true
            }
        }

        // 跳过隐藏的应用（名称以 . 开头）
        if name.hasPrefix(".") {
            return true
        }

        // 跳过一些特殊路径
        if path.contains("/System/Library/CoreServices/") ||
           path.contains("/Library/Application Support/") {
            return true
        }

        return false
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
