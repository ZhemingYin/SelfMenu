//
//  CookingActivity.swift
//  CookingActivity
//
//  Created by 尹哲铭 on 27.11.25.
//

import WidgetKit
import SwiftUI
import ActivityKit

struct CookingActivity: Widget {
    // 这是一个标识符，随便起
    let kind: String = "CookingActivity"

    var body: some WidgetConfiguration {
        // Live Activity
        ActivityConfiguration(for: CookingAttributes.self) { context in
            HStack {
                HStack {
                    // 左边：锅的图标
                    Image(systemName: "frying.pan.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("\(context.state.menuName)")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                .padding(.leading, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 右边：自动刷新的计时器
                // timerInterval: 传入 开始时间...当前时间，系统会自动显示 0:01, 0:02...
                Text(context.state.startTime, style: .timer)
                    .multilineTextAlignment(.trailing)
                    .font(.title)
                    .bold()
                    .foregroundColor(.orange)
                    .frame(width: 80, alignment: .trailing)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .activitySystemActionForegroundColor(Color.orange) // 系统按钮颜色
            
        } dynamicIsland: { context in
            DynamicIsland {
                // A. 长按展开后的区域 (Expanded)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        HStack {
                            Image(systemName: "frying.pan.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.orange)
                            
                            VStack(alignment: .leading) {
                                Text(context.state.menuName)
                                    .font(.system(size: 30))
                                    .bold()
                                    .foregroundStyle(.primary)
    //                                .padding(.bottom, 2)
                                
                                Text(context.state.startTime, style: .timer)
                                    .font(.system(size: 30))
                                    .bold()
                                    .foregroundColor(.orange)
                                    .contentTransition(.numericText())
                            }
                            .frame(width: 100, height:100)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Link(destination: URL(string: "selfmenu://stopCooking")!) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 50))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.secondary) // 白叉红底
                        }
                        .frame(width: 100, alignment: .trailing)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                
            } compactLeading: {
                // B. 收起状态 - 左边 (显示小锅)
                Image(systemName: "frying.pan.fill")
                    .foregroundColor(.orange)
                    .padding(.leading, 3)
                
            } compactTrailing: {
                // C. 收起状态 - 右边 (显示计时)
                Text(context.state.startTime, style: .timer)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.orange)
                    .frame(width: 40) // 限制宽度
                    .padding(.trailing, 3)
                
            } minimal: {
                // D. 最小化状态 (当有多个 Live Activity 时显示的小圆圈)
                Image(systemName: "frying.pan.fill")
                    .foregroundColor(.orange)
            }
        }
    }
}

// 预览代码 (Xcode 15+)
#Preview("Notification", as: .content, using: CookingAttributes(totalTime: 0)) {
   CookingActivity()
} contentStates: {
    CookingAttributes.ContentState(startTime: Date(), menuName: "Steak")
}
