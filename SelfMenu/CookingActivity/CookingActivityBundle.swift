//
//  CookingActivityBundle.swift
//  CookingActivity
//
//  Created by 尹哲铭 on 27.11.25.
//

import WidgetKit
import SwiftUI

@main
struct CookingActivityBundle: WidgetBundle {
    var body: some Widget {
        // 这里调用的必须是 CookingActivity.swift 里定义的那个 struct 名字
        CookingActivity()
        
        // 如果你将来还想要普通的桌面小组件，可以写成：
        // CookingActivity()
        // MyHomeWidget()
    }
}
