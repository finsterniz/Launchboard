//
//  SearchBarView.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import SwiftUI

/// 搜索栏视图 - 支持实时搜索和回车启动
struct SearchBarView: View {
    @Binding var searchText: String
    let onSubmit: () -> Void
    
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack {
            // 搜索图标
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            // 搜索输入框
            TextField("搜索应用...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isSearchFocused)
                .onSubmit {
                    onSubmit()
                }
                // ESC 键处理将在父视图中实现
            
            // 清除按钮
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    isSearchFocused = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .foregroundColor(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.quaternaryLabelColor), lineWidth: 1)
                )
        )
        .onAppear {
            // 视图出现时自动聚焦搜索框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var searchText = ""

        var body: some View {
            SearchBarView(searchText: $searchText) {
                print("搜索提交: \(searchText)")
            }
            .padding()
            .frame(width: 400)
        }
    }

    return PreviewWrapper()
}
