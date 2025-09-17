//
//  AppGridView.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import SwiftUI

/// 应用网格视图 - 7x5 网格布局显示应用
struct AppGridView: View {
    let apps: [AppItem]
    let onAppTap: (AppItem) -> Void
    
    // 7x5 网格配置
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 7)
    private let maxItems = 35 // 7 * 5
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(0..<maxItems, id: \.self) { index in
                if index < apps.count {
                    // 显示应用图标
                    AppIconView(app: apps[index]) {
                        onAppTap(apps[index])
                    }
                } else {
                    // 空白占位符
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 64, height: 64)
                }
            }
        }
        .padding()
    }
}

#Preview {
    // 创建示例应用数据
    let sampleApps = [
        AppItem(
            name: "Safari",
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            path: "/Applications/Safari.app",
            iconPath: nil,
            position: nil
        ),
        AppItem(
            name: "Finder",
            displayName: "Finder",
            bundleIdentifier: "com.apple.finder",
            path: "/System/Library/CoreServices/Finder.app",
            iconPath: nil,
            position: nil
        ),
        AppItem(
            name: "Mail",
            displayName: "Mail",
            bundleIdentifier: "com.apple.mail",
            path: "/Applications/Mail.app",
            iconPath: nil,
            position: nil
        )
    ]
    
    return AppGridView(apps: sampleApps) { app in
        print("点击应用: \(app.displayName)")
    }
    .frame(width: 600, height: 400)
    .background(.regularMaterial)
}
