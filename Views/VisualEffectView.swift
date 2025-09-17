//
//  VisualEffectView.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import SwiftUI
import AppKit

/// NSVisualEffectView 的 SwiftUI 包装器
/// 提供毛玻璃背景效果，类似 LaunchPad 的视觉风格
struct VisualEffectView: NSViewRepresentable {
    
    /// 毛玻璃材质类型
    let material: NSVisualEffectView.Material
    
    /// 混合模式
    let blendingMode: NSVisualEffectView.BlendingMode
    
    /// 状态（活跃/非活跃）
    let state: NSVisualEffectView.State
    
    /// 默认初始化器
    /// - Parameters:
    ///   - material: 毛玻璃材质，默认为 .hudWindow
    ///   - blendingMode: 混合模式，默认为 .behindWindow
    ///   - state: 视觉效果状态，默认为 .active
    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        
        // 配置毛玻璃效果
        effectView.material = material
        effectView.blendingMode = blendingMode
        effectView.state = state
        
        // 设置外观
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true
        
        return effectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // 更新视觉效果属性
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

/// 预设的毛玻璃效果样式
extension VisualEffectView {
    
    /// LaunchPad 风格的毛玻璃效果
    static var launchPadStyle: VisualEffectView {
        VisualEffectView(
            material: .hudWindow,
            blendingMode: .behindWindow,
            state: .active
        )
    }
    
    /// 深色毛玻璃效果
    static var darkStyle: VisualEffectView {
        VisualEffectView(
            material: .fullScreenUI,
            blendingMode: .behindWindow,
            state: .active
        )
    }
    
    /// 浅色毛玻璃效果
    static var lightStyle: VisualEffectView {
        VisualEffectView(
            material: .windowBackground,
            blendingMode: .behindWindow,
            state: .active
        )
    }
    
    /// 侧边栏风格
    static var sidebarStyle: VisualEffectView {
        VisualEffectView(
            material: .sidebar,
            blendingMode: .behindWindow,
            state: .active
        )
    }
}

#Preview {
    ZStack {
        // 背景图片用于演示毛玻璃效果
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.blue, .purple, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        
        // 毛玻璃效果
        VisualEffectView.launchPadStyle
            .frame(width: 300, height: 200)
            .overlay {
                VStack {
                    Text("LaunchBoard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("毛玻璃效果预览")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
    }
    .frame(width: 400, height: 300)
}
