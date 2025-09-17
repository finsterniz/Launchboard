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
                if url.pathExtension == "app" {
                    do {
                        let resourceValues = try url.resourceValues(forKeys: [.isApplicationKey])
                        if resourceValues.isApplication == true {
                            applicationURLs.append(url)
                        }
                    } catch {
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

        let expandedScanPaths = [
            "/Applications",
            "/System/Applications",
            "/Applications/Utilities",
            NSHomeDirectory() + "/Applications"
        ]

        for path in expandedScanPaths {
            let apps = await scanDirectory(path)
            allApps.append(contentsOf: apps)
        }

        let uniqueApps = removeDuplicates(from: allApps)

        print("目录扫描完成，共找到 \(uniqueApps.count) 个应用")
        return uniqueApps
    }
    
    // MARK: - 私有方法
    
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
    
    private func createAppItem(from appPath: String) -> AppItem? {
        guard FileManager.default.fileExists(atPath: appPath) else {
            print("应用不存在: \(appPath)")
            return nil
        }

        guard appPath.hasSuffix(".app") else {
            print("不是 .app 文件: \(appPath)")
            return nil
        }

        guard let bundle = Bundle(path: appPath) else {
            print("无法创建 Bundle: \(appPath)")
            return createAppItemFallback(from: appPath)
        }

        let bundleIdentifier = bundle.bundleIdentifier ?? "unknown.\(UUID().uuidString)"

        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
                  bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                  bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String ??
                  URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent

        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? name

        if shouldSkipApplication(name: name, bundleId: bundleIdentifier, path: appPath) {
            return nil
        }

        return AppItem(
            name: name,
            displayName: displayName,
            bundleIdentifier: bundleIdentifier,
            path: appPath,
            iconPath: nil,
            position: nil
        )
    }

    private func createAppItemFallback(from appPath: String) -> AppItem? {
        let url = URL(fileURLWithPath: appPath)
        let name = url.deletingPathExtension().lastPathComponent

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

    private func shouldSkipApplication(name: String, bundleId: String, path: String) -> Bool {
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

        if name.hasPrefix(".") {
            return true
        }

        if path.contains("/System/Library/CoreServices/") ||
           path.contains("/Library/Application Support/") {
            return true
        }

        return false
    }

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

