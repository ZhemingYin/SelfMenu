//
//  ContentView.swift
//  SelfMenu
//
//  Created by 尹哲铭 on 19.11.25.
//

import SwiftUI
import SwiftData

// MARK: - 卡片正面
struct CardFront: View {
    var body: some View {
        ZStack {
            // 背景材质 + 圆角
            RoundedRectangle(cornerRadius: 50)
                .fill(Color.white.opacity(0.15)) // 轻微白色以增强玻璃质感
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 50))
                .overlay(
                    // 边缘光泽（增加立体感）
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.6),
                                    .white.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: .black.opacity(0.15), radius: 50, x: 0, y: 5)
            
            Text("Front")
                .font(.largeTitle)
                .foregroundColor(.primary)
        }
        .background(.clear)
    }
}

// MARK: - 卡片背面
struct CardBack: View {
    var body: some View {
        ZStack {
            // 背景材质 + 圆角
            RoundedRectangle(cornerRadius: 50)
                .fill(Color.white.opacity(0.25)) // 轻微白色以增强玻璃质感
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 50))
                .shadow(color: .black.opacity(0.15), radius: 50, x: 0, y: 5) // 阴影让卡片浮在背景上
                .overlay(
                    // 边缘光泽（增加立体感）
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.6),
                                    .white.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                
            
            Text("Back")
                .font(.largeTitle)
                .foregroundColor(.primary)
        }
    }
}


struct FlipCardView:View {
    @Binding var currentIndex: Int
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuItems.MenuIndex) private var menuItems: [MenuItems]
    
    @State private var flipped = false
    @State private var rotation = 0.0
    
    private var filteredMenuItem: [MenuItems] {
        return menuItems.filter {
            $0.MenuIndex == currentIndex
        }
    }
    
    var body: some View {
        ZStack {
            // 卡片正面
            CardFront()
                .opacity(flipped ? 0 : 1)
                .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))

            // 卡片背面
            CardBack()
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(rotation + 180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(width: 300, height: 500)
        .background(Color.clear)
        .onTapGesture {
            withAnimation(.spring(duration: 0.6)) {
                rotation += 180
                flipped.toggle()
            }
        }
    }
}

struct BottomSwitcher: View {
    @Binding var currentIndex: Int
    @Binding var totalPages: Int
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuItems.MenuIndex) private var menuItems: [MenuItems]
    
    var body: some View {
        HStack {
            
            Spacer()
            
            // 占位按钮
            Button(action: {}) {
                Image(systemName: "list.bullet")
                    .font(.body.weight(.medium))
                    .foregroundColor(.clear) // 完全透明
                    .frame(width: 44, height: 44)
                    .background(Color.clear) // 透明背景
                    .clipShape(Circle())
            }
            .disabled(true) // 禁用点击
            .allowsHitTesting(false) // 禁止触摸事件
            
            Spacer()
            
            if !menuItems.isEmpty {
                PageControl(currentPage: $currentIndex, numberOfPages: totalPages)
            } else {
                Text("Tap here to add a new page")
                    .bold()
                    .font(.title3)
                Image(systemName: "arrowshape.right")
                    .foregroundStyle(.blue)
                    .bold()
            }
            
            Spacer()
            
            Menu {
                // 遍历所有页面标题，生成菜单项
                ForEach(menuItems.reversed(), id: \.MenuIndex) { menuItem in
                    Button {
                        currentIndex = menuItem.MenuIndex
                    } label: {
                        Label(
                            menuItem.MenuName,
                            systemImage: menuItem.MenuIndex == currentIndex ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
                
                Divider() // 分割线
                
                Button {
                    print("Add Page")
//                                currentPage = totalPages - 1
                } label: {
                    Label("Add new page", systemImage: "plus")
                }
                
            } label: {
                // 原来的按钮外观保持不变
                Image(systemName: "list.bullet")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.clear)
                    .clipShape(Circle())
                    .padding(.horizontal, 1)
            }
            
            Spacer()
        }
    }
}

// UIPageControl 的 SwiftUI 包装器
struct PageControl: UIViewRepresentable {
    @Binding var currentPage: Int
    var numberOfPages: Int
    
    func makeUIView(context: Context) -> UIPageControl {
        let pageControl = UIPageControl()  // 创建 UIKit 的 UIPageControl 实例
        pageControl.numberOfPages = numberOfPages  // 设置总页数
        pageControl.currentPage = currentPage  // 设置当前页码
        pageControl.currentPageIndicatorTintColor = .systemBlue  // 当前点的颜色
        pageControl.pageIndicatorTintColor = .systemGray  // 其他点的颜色
        pageControl.addTarget(  // 添加事件监听
            context.coordinator,
            action: #selector(Coordinator.updateCurrentPage(sender:)),
            for: .valueChanged
        )
        return pageControl  // 返回配置好的 UIKit 组件
    }
    
    func updateUIView(_ uiView: UIPageControl, context: Context) {
        uiView.currentPage = currentPage  // 同步当前页码
        uiView.numberOfPages = numberOfPages  // 同步总页数
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)  // 创建协调器实例，传入当前 PageControl
    }
    
    class Coordinator: NSObject {
        var parent: PageControl  // 持有父级 PageControl 的引用
        
        init(_ parent: PageControl) {
            self.parent = parent  // 初始化时保存父级引用
        }
        
        @objc func updateCurrentPage(sender: UIPageControl) {
            parent.currentPage = sender.currentPage  // 更新 SwiftUI 状态
        }
    }
}

struct ContentView: View {
    @State private var initialSelfMenuItems = true
    @State private var currentIndex: Int = 0
    @State private var totalPages: Int = 0
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuItems.MenuIndex) private var menuItems: [MenuItems]
//    var totalPages: Int {
//        menuItems.count
//    }
    
    var body: some View {
            // 使用 UIPageControl
        VStack {
            Spacer()
            
            FlipCardView(currentIndex:$currentIndex)
        
            Spacer()
            
            BottomSwitcher(currentIndex:$currentIndex, totalPages:$totalPages)
        }
        .onAppear {
            if initialSelfMenuItems {
                initialFirstSelfMenu()
            }
        }
        .onChange(of: menuItems) { oldValue, newValue in
            totalPages = newValue.count
        }
    }
    
    private func initialFirstSelfMenu() {
        let initial1Item = MenuItems(MenuImageData: nil, MenuIndex: 0, MenuName: "Pizza", MenuMaterials:["Pork", "Flour"], MenuSteps: ["Cook", "Bake"])
        modelContext.insert(initial1Item)
        let initial2Item = MenuItems(MenuImageData: nil, MenuIndex: 1, MenuName: "Spaghetti", MenuMaterials:["Spaghetti", "Pork", "Sauce"], MenuSteps: ["Boil", "Cook", "Stir"])
        modelContext.insert(initial2Item)
        try? modelContext.save()
        print("Intialization of SwiftData")
        
        initialSelfMenuItems.toggle()
    }
}


#Preview {
    ContentView()
        .modelContainer(for: MenuItems.self, inMemory: true)
}
