//
//  AppIconView.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import SwiftUI
import AppKit

/// 单个应用图标视图 - 支持点击启动
struct AppIconView: View {
    let app: AppItem
    let onTap: () -> Void
    
    @State private var isHovered = false
    @State private var appIcon: NSImage?
    
    var body: some View {
        VStack(spacing: 4) {
            // 应用图标
            Group {
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    // 默认图标占位符
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "app")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            // 应用名称
            Text(app.displayName)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80, height: 32)
                .truncationMode(.tail)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadAppIcon()
        }
        .contextMenu {
            // 右键菜单
            Button("打开") {
                onTap()
            }
            
            Button("在 Finder 中显示") {
                NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: "")
            }
            
            Divider()
            
            Button("应用信息") {
                showAppInfo()
            }
        }
    }
    
    /// 加载应用图标
    private func loadAppIcon() {
        Task {
            let icon = app.icon
            await MainActor.run {
                self.appIcon = icon
            }
        }
    }
    
    /// 显示应用信息
    private func showAppInfo() {
        let alert = NSAlert()
        alert.messageText = app.displayName
        alert.informativeText = """
        Bundle ID: \(app.bundleIdentifier)
        路径: \(app.path)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}

#Preview {
    let sampleApp = AppItem(
        name: "Safari",
        displayName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        path: "/Applications/Safari.app",
        iconPath: nil,
        position: nil
    )
    
    return AppIconView(app: sampleApp) {
        print("点击了 Safari")
    }
    .padding()
}
