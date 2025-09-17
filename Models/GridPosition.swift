//
//  GridPosition.swift
//  LaunchBoard
//
//  Created by Haoyuan Yan on 17.09.25.
//

import Foundation

/// 网格位置信息
struct GridPosition: Codable, Equatable {
    let row: Int        // 行索引 (0-4)
    let column: Int     // 列索引 (0-6)
    let page: Int       // 页面索引 (0-based)
    
    /// 计算在当前页面的线性索引
    var linearIndex: Int {
        return row * 7 + column
    }
    
    /// 从线性索引创建网格位置
    static func from(linearIndex: Int, page: Int = 0) -> GridPosition {
        let row = linearIndex / 7
        let column = linearIndex % 7
        return GridPosition(row: row, column: column, page: page)
    }
    
    /// 检查位置是否有效 (7x5 网格)
    var isValid: Bool {
        return row >= 0 && row < 5 && column >= 0 && column < 7 && page >= 0
    }
}
