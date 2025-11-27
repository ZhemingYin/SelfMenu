//
//  CookingAttributes.swift
//  SelfMenu
//
//  Created by 尹哲铭 on 27.11.25.
//

import ActivityKit
import SwiftUI

struct CookingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // 动态数据：这里我们只需要开始时间，系统会自动计算流逝时间，不需要每一秒刷新一次
        var startTime: Date
        var menuName: String
    }
    
    // 静态数据（活动开始后不会变的数据）
    var totalTime: Int
}
