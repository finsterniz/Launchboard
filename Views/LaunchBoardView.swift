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
            VisualEffectView.launchPadStyle
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
                        cells: viewModel.currentPageCells,
                        onAppTap: { app in
                            viewModel.launchApp(app)
                        },
                        onDragStarted: { app in
                            print("开始拖拽应用: \(app.displayName)")
                        },
                        onDragEnded: {
                            print("拖拽结束")
                        },
                        onAppMoved: { app, targetIndex in
                            // 兼容旧回调：默认视为插入到该 cell 之前
                            viewModel.handleDrop(app, action: .insertBefore(indexInPage: targetIndex))
                        },
                        onDropAction: { app, action in
                            viewModel.handleDrop(app, action: action)
                        },
                        onPageChange: { targetPage in
                            viewModel.goToPage(targetPage)
                        },
                        currentPage: viewModel.currentPage,
                        totalPages: viewModel.totalPages
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
    }
}

#Preview {
    LaunchBoardView()
        .frame(width: 800, height: 600)
}

