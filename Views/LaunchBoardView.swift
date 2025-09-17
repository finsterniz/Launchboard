//
//  LaunchBoardView.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import SwiftUI

/// 主视图 - LaunchBoard 的核心界面
struct LaunchBoardView: View {
    @StateObject private var viewModel = LaunchBoardViewModel()
    
    var body: some View {
        ZStack {
            // 毛玻璃背景
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 搜索栏
                SearchBarView(searchText: $viewModel.searchText) {
                    viewModel.launchFirstSearchResult()
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)
                
                // 应用网格
                if viewModel.isLoading {
                    ProgressView("正在扫描应用...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AppGridView(
                        apps: viewModel.currentPageApps,
                        onAppTap: { app in
                            viewModel.launchApp(app)
                        }
                    )
                    .padding(.horizontal, 40)
                }
                
                // 分页导航
                if viewModel.totalPages > 1 {
                    HStack {
                        Button("上一页") {
                            viewModel.goToPreviousPage()
                        }
                        .disabled(!viewModel.canGoToPreviousPage)
                        
                        Spacer()
                        
                        Text("\(viewModel.currentPage + 1) / \(viewModel.totalPages)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("下一页") {
                            viewModel.goToNextPage()
                        }
                        .disabled(!viewModel.canGoToNextPage)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
                
                Spacer()
            }
        }
        .onAppear {
            // 视图出现时加载数据
            if viewModel.apps.isEmpty {
                Task {
                    await viewModel.scanApplications()
                }
            }
        }
        // ESC 键处理将通过其他方式实现
    }
}

/// 毛玻璃效果视图
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

#Preview {
    LaunchBoardView()
        .frame(width: 800, height: 600)
}
