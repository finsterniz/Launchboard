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
    @Namespace private var folderNS   // 用于 matchedGeometryEffect
    
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
                        onGroupTap: { group in
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.2)) {
                                viewModel.openGroup(group)
                            }
                        },
                        onDragStarted: { app in
                            print("开始拖拽应用: \(app.displayName)")
                        },
                        onDragEnded: {
                            print("拖拽结束")
                        },
                        onAppMoved: { app, targetIndex in
                            viewModel.handleDrop(app, action: .insertBefore(indexInPage: targetIndex))
                        },
                        onDropAction: { app, action in
                            viewModel.handleDrop(app, action: action)
                        },
                        onPageChange: { targetPage in
                            viewModel.goToPage(targetPage)
                        },
                        currentPage: viewModel.currentPage,
                        totalPages: viewModel.totalPages,
                        animationNamespace: folderNS,
                        expandedGroupID: viewModel.expandedGroup?.id
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
            
            // 分组展开覆盖层（类似 iPad 文件夹展开）
            if let expandedGroup = viewModel.expandedGroup {
                AppGroupOverlayView(
                    group: expandedGroup,
                    namespace: folderNS,
                    onClose: {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.2)) {
                            viewModel.closeExpandedGroup()
                        }
                    },
                    onAppTap: { app in viewModel.launchApp(app) }
                )
                .transition(.identity) // 使用 matchedGeometryEffect，无需额外过渡
                .zIndex(1)
            }
        }
        .onAppear {
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

