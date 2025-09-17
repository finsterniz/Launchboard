//
//  LaunchBoardApp.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import SwiftUI
import AppKit

@main
struct LaunchBoardApp: App {

    init() {
        // 配置应用启动时的窗口行为
        setupWindowAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Color.clear) // 透明背景
        }
        .windowStyle(.hiddenTitleBar) // 隐藏标题栏
        .windowResizability(.contentSize) // 固定窗口大小
        .windowToolbarStyle(.unifiedCompact(showsTitle: false)) // 紧凑工具栏样式
        .commands {
            // 移除默认菜单项
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
        }
    }

    /// 配置窗口外观
    private func setupWindowAppearance() {
        // 延迟设置应用激活策略，确保 NSApp 已初始化
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
        }

        // 监听窗口创建事件
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow {
                self.configureWindow(window)
            }
        }

        // 延迟配置窗口，给 SwiftUI 时间创建窗口
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.windows.first {
                self.configureWindow(window)
            }
        }
    }

    /// 配置具体窗口属性
    private func configureWindow(_ window: NSWindow) {
        // 设置窗口样式
        window.styleMask = [.borderless, .resizable]
        window.isMovableByWindowBackground = false  // 禁用窗口背景拖拽，避免与应用图标拖拽冲突
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = true

        // 设置窗口层级（始终在前）
        window.level = .floating

        // 设置窗口尺寸为屏幕的 80%，类似 LaunchPad
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowWidth = screenFrame.width * 0.8
            let windowHeight = screenFrame.height * 0.8

            // 设置窗口大小和位置
            window.setFrame(
                NSRect(
                    x: screenFrame.midX - windowWidth / 2,
                    y: screenFrame.midY - windowHeight / 2,
                    width: windowWidth,
                    height: windowHeight
                ),
                display: true
            )
        } else {
            // 备用方案：固定尺寸并居中
            window.setFrame(NSRect(x: 200, y: 200, width: 1000, height: 700), display: true)
            window.center()
        }

        // 设置窗口标题
        window.title = "LaunchBoard"

        // 添加 ESC 键监听
        setupKeyboardMonitoring(for: window)
    }

    /// 设置键盘监听
    private func setupKeyboardMonitoring(for window: NSWindow) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // ESC 键
                NSApp.terminate(nil)
                return nil
            }
            return event
        }
    }
}
