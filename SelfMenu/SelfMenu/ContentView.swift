//
//  ContentView.swift
//  SelfMenu
//
//  Created by 尹哲铭 on 19.11.25.
//

import SwiftUI
import SwiftData
import RealityKit
import Combine
import PhotosUI
import UIKit


class HapticManager {
    static let shared = HapticManager()
    
    // 轻震动
    func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // 中等震动
    func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // 重震动
    func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    // 成功反馈
    func successNotification() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // 错误反馈
    func errorNotification() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // 警告反馈
    func warningNotification() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - 卡片正面
struct CardFront: View {
    @Binding var currentIndex: Int
    @Binding var isEditingMenu: Bool
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuItems.MenuIndex) private var menuItems: [MenuItems]
    private var currentMenuItem: MenuItems? {
        menuItems.first { $0.MenuIndex == currentIndex }
    }
    
    @State private var newMenuName: String = ""
    @State private var selectedImageItem: PhotosPickerItem? = nil
    @State private var showingPhotoPicker: Bool = false
    
    var body: some View {
        ZStack {
            // 背景材质 + 圆角
            RoundedRectangle(cornerRadius: 50)
                .fill(Color.white.opacity(0.05)) // 轻微白色以增强玻璃质感
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 50))
                .overlay(
                    // 边缘光泽（增加立体感）
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
//                .shadow(color: .black.opacity(0.15), radius: 50, x: 0, y: 5) // 阴影让卡片浮在背景上
                
            VStack {
                Spacer()
                if let imageData = currentMenuItem?.MenuImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
//                        .padding(.bottom, 20)
                        .onLongPressGesture(minimumDuration: 0.2) {
                            if isEditingMenu {
                                showingPhotoPicker = true
                            }
                        }
                    
                }
                else {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color.secondary, style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .frame(width: 240, height: 350)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                
                Spacer()
                
                HStack {
                    Spacer()
                    TextField(
                        "To-do",
                        text: $newMenuName,
                    )
                    .fixedSize()
                    .frame(minWidth: 50)
                    .font(.title)
                    .bold()
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .submitLabel(.done)
                    .onSubmit {
                        updateCardFront()
                    }
                    .disabled(!isEditingMenu)
                    Spacer()
                }
                .padding(.bottom, 50)
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedImageItem)
        .onChange(of: selectedImageItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    if let item = currentMenuItem {
                        item.MenuImageData = data
                        try? modelContext.save()
                    }
                }
            }
        }
        .onAppear {
            newMenuName = currentMenuItem?.MenuName ?? "New Menu"
        }
        .onChange(of: currentIndex) { oldValue, newValue in
            newMenuName = currentMenuItem?.MenuName ?? "New Menu"
        }
        .onChange(of: menuItems) { oldValue, newValue in
            newMenuName = currentMenuItem?.MenuName ?? "New Menu"
        }
    }
    
    private func updateCardFront() {
        if let updateCardFrontItem = menuItems.first(
            where: { $0.MenuIndex == currentIndex})
        {
            updateCardFrontItem.MenuName = newMenuName
        } else {
            print("The name of menu item is not found")
        }
        
        do {
            try modelContext.save()
            print("The menu name is updated")
        } catch {
            print("Update menu name failed")
        }
    }
}

// MARK: - 卡片背面
struct CardBack: View {
    @Binding var currentIndex: Int
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuItems.MenuIndex) private var menuItems: [MenuItems]
    private var currentMenuItem: MenuItems? {
        menuItems.first { $0.MenuIndex == currentIndex }
    }
    
    var body: some View {
        ZStack {
            // 背景材质 + 圆角
            RoundedRectangle(cornerRadius: 50)
                .fill(Color.white.opacity(0.05)) // 轻微白色以增强玻璃质感
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 50))
                .overlay(
                    // 边缘光泽（增加立体感）
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
//                .shadow(color: .black.opacity(0.15), radius: 50, x: 0, y: 5) // 阴影让卡片浮在背景上
            ScrollView {
                VStack(alignment: .leading) {
                    if let item = currentMenuItem {
                        Text("Materials:")
                            .font(.title2)
                            .bold()
                            .padding(.top, 20)
                        
                        ForEach(item.MenuMaterialNames.indices, id: \.self) { index1 in
                            let name = item.MenuMaterialNames[index1]
                            let count = item.MenuMaterialCounts[index1]
                            let comment = item.MenuMaterialComments[index1]

                            HStack {
                                Text("• \(name), ")
                                    .font(.title3)
                                    .foregroundColor(.primary)

                                Text("\(count)")
                                    .font(.title3)
                                    .foregroundColor(.primary)

                                if comment != "None" {
                                    Text(" — \(comment)")
                                        .font(.title3)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        
                        Divider()
                            .foregroundStyle(.primary)
                            .padding(.vertical, 10)
                        
                        Text("Steps:")
                            .font(.title2)
                            .bold()
                        
                        ForEach(item.MenuSteps.indices, id: \.self) { index2 in
                            let step = item.MenuSteps[index2]
                            let stepImageData = item.MenuStepImageData[index2]

                            HStack {
                                Text("\(index2 + 1). ")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                                
                                Text("\(step)")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            }
                        }
                    } else {
                        Text("Can't find the corresponding materials")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
        }
    }
}


struct FlipCardView:View {
    @Binding var currentIndex: Int
    
    @State private var flipped = false
    @State private var rotation = 0.0
    @State private var verticalOffset: CGFloat = 0
    @State private var baseVerticalOffset: CGFloat = 0
    @State private var horizontalOffset: CGFloat = 0
    @State private var baseHorizontalOffset: CGFloat = 0
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuItems.MenuIndex) private var menuItems: [MenuItems]
    
    @State private var showingDeletePageConfirm = false
    @State private var deletePulse = false
    @State private var isEditingMenu = false
    @State private var isSavingEditingCardFront = false
    @State private var isSavingEditingCardBack = false
    
    var body: some View {
        ZStack {
            // Background action layer (stays behind card)
            ZStack {
                // Top delete button
                VStack {
                    Spacer()
                    Button {
                        showingDeletePageConfirm.toggle()
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.title2)
                            .foregroundColor(.red)
                            .padding()
                            .glassEffect()
                            .opacity(min(max((-verticalOffset) / 120, 0), 1))
                            .scaleEffect(0.8 + 0.2 * min(max((-verticalOffset) / 120, 0), 1))
                            .scaleEffect(deletePulse ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.4), value: deletePulse)
                    }
                    .padding(.bottom, 20)
                    .confirmationDialog("Delete Page", isPresented: $showingDeletePageConfirm) {
                        Button("Delete", role: .destructive) {
                            deleteMenu()
                            showingDeletePageConfirm.toggle()
                            HapticManager.shared.errorNotification()
                            baseVerticalOffset = 0
                            verticalOffset = 0
                        }
                    } message: {
                        Text("Delete this Menu? This action can't be undone.")
                    }
                }
                
                // Bottom edit button
                VStack {
                    if !isEditingMenu {
                        Button {
                            isEditingMenu = true
                        } label: {
                            Label("Edit", systemImage: "wrench.adjustable")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .padding()
                                .glassEffect()
                                .opacity(min(max(verticalOffset / 120, 0), 1))
                                .scaleEffect(0.8 + 0.2 * min(max(verticalOffset / 120, 0), 1))
                                .scaleEffect(isEditingMenu ? 1.3 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.4), value: isEditingMenu)
                        }
                        .padding(.top, 20)
                    } else {
                        Button {
                            isEditingMenu = true
                        } label: {
                            VStack {
                                Label("Editing", systemImage: "wrench.adjustable")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .background(Color.clear)
                                    .padding()
                                    .glassEffect()
                                    .opacity(min(max(verticalOffset / 120, 0), 1))
                                    .scaleEffect(0.8 + 0.2 * min(max(verticalOffset / 120, 0), 1))
                                
                                Text("Long tap to edit the photo.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .background(Color.clear)
                            }
                        }
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                }
            }
            
            ZStack {
                // 卡片正面
                CardFront(currentIndex:$currentIndex, isEditingMenu:$isEditingMenu)
                    .opacity(flipped ? 0 : 1)
                    .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))

                // 卡片背面
                CardBack(currentIndex:$currentIndex)
                    .opacity(flipped ? 1 : 0)
                    .rotation3DEffect(.degrees(rotation + 180), axis: (x: 0, y: 1, z: 0))
            }
            .offset(x: horizontalOffset, y: verticalOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // 让卡片在当前停靠位置的基础上继续拖动
                        verticalOffset = baseVerticalOffset + value.translation.height
                        horizontalOffset = baseHorizontalOffset + value.translation.width
                    }
                    .onEnded { value in
                            
                        // ---- 向上滑 —— Delete ----
                        if verticalOffset < -150 && verticalOffset > -220 {
                            // 停在刚好露出 Delete 按钮的位置
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                baseVerticalOffset = -120
                                verticalOffset = -120
                            }
                            HapticManager.shared.lightImpact()
                        }
                        
                        // ---- 向上滑更远 —— Delete ----
                        else if verticalOffset < -220 {
                            deletePulse = true
                            withAnimation(.easeOut(duration: 0.25)) {
                                baseVerticalOffset = -1000
                                verticalOffset = -1000
                            }

                            // 等待动画完成后再执行删除动作
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if currentIndex == (menuItems.count-1) {
                                    horizontalOffset = -400
                                } else {
                                    horizontalOffset = 400
                                }
                                deleteMenu()
                                deletePulse = false
                                HapticManager.shared.errorNotification()
                                baseVerticalOffset = 0
                                verticalOffset = 0

                                // 返回初始位置
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    horizontalOffset = 0
                                }
                            }
                        }
                        
                        // ---- 向下滑 —— Edit ----
                        else if verticalOffset > 150 && verticalOffset < 200 {
                            // 停在刚好露出 Edit 按钮的位置
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                baseVerticalOffset = 120
                                verticalOffset = 120
                                baseHorizontalOffset = 0
                                horizontalOffset = 0
                            }
                            HapticManager.shared.lightImpact()
                        }
                        
                        // ---- 向下滑更远 —— Edit ----
                        else if verticalOffset > 200 {
                            // 停在刚好露出 Edit 按钮的位置
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                baseVerticalOffset = 120
                                verticalOffset = 120
                                baseHorizontalOffset = 0
                                horizontalOffset = 0
                            }
                            isEditingMenu = true
                            HapticManager.shared.lightImpact()
                        }
                        
                        // ---- 向右滑 —— 上一页 ----
                        else if horizontalOffset > 120 && currentIndex > 0 {
                            currentIndex -= 1
                            HapticManager.shared.lightImpact()
                        }
                        
                        // ---- 向左滑 —— 下一页 ----
                        else if horizontalOffset < -120 && currentIndex < menuItems.count-1 {
                            // 向左滑动，下一页
                            currentIndex += 1
                        }
                        
                        // ---- 回弹到中心 ----
                        else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                baseVerticalOffset = 0
                                verticalOffset = 0
                                baseHorizontalOffset = 0
                                horizontalOffset = 0
                                isEditingMenu = false
                            }
                        }
                    }
            )
            .onTapGesture {
                withAnimation(.spring(duration: 0.6)) {
                    rotation += 180
                    flipped.toggle()
                }
            }
        }
        .frame(width: 300, height: 500)
//        .frame(width: 600, height: 800)
        .background(Color.clear)
        .onChange(of: currentIndex) { oldValue, newValue in
            let direction: CGFloat = newValue > oldValue ? 1 : -1
            
            // 新卡片先从屏幕侧面开始
            horizontalOffset = 400 * direction
            
            // 重置翻转状态
            flipped = false
            rotation = 0
            
            // 垂直位置归零
            verticalOffset = 0
            baseVerticalOffset = 0
            
            // 动画滑入
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                horizontalOffset = 0
            }
        }
    }
    
    private func deleteMenu() {
        let totalPages = menuItems.count
        for index in currentIndex..<totalPages {
            
            if index == currentIndex {
                if let deleteMenuItem = menuItems.first(
                    where: { $0.MenuIndex == currentIndex }) {
                    modelContext.delete(deleteMenuItem)
                } else {
                    print("The Menu to be deleted fails to find.")
                }
            } else {
                if let menuDataToUpdate = menuItems.first(
                    where: { $0.MenuIndex == index })
                {
                    menuDataToUpdate.MenuIndex -= 1
                } else {
                    print("The other menu index \(index) is not found after deleting the page")
                }
            }
            
            do {
                try modelContext.save()
            } catch {
                print("Delete Page unsuccessfully\(error.localizedDescription)")
            }
            
            if currentIndex == (totalPages-1) {
                currentIndex -= 1
            } else {
                currentIndex = currentIndex
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
    
    @Binding var isAddingMenu: Bool
    
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
//                ForEach(menuItems.reversed(), id: \.MenuIndex) { menuItem in
                ForEach(menuItems, id: \.MenuIndex) { menuItem in
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
                    // 1. 插入新菜单项
                    let newIndex = menuItems.count
                    let newItem = MenuItems(
                        MenuImageData: nil,
                        MenuIndex: newIndex,
                        MenuName: "New Menu",
                        MenuMaterialNames: [],
                        MenuMaterialCounts: [],
                        MenuMaterialComments: [],
                        MenuSteps: [],
                        MenuStepImageData: [nil],
                        Cookingtimes: 0,
                        MeanCookingTime: 0
                    )
                    modelContext.insert(newItem)
                    
                    // 保存到数据库
                    try? modelContext.save()
                    
                    // 2. 使用动画切换到最后一页
                    DispatchQueue.main.async {
                        flipToPage(newIndex)
                    }
                    
                } label: {
                    Label("Add new Menu", systemImage: "plus")
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
    
    func flipToPage(_ targetIndex: Int) {
        guard currentIndex < targetIndex else { return } // 翻到目标页停止
        withAnimation(.spring()) {
            currentIndex += 1
        }
        
        // 延迟下一页翻转
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            flipToPage(targetIndex)
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
    
    @State private var isAddingMenu: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuItems.MenuIndex) private var menuItems: [MenuItems]
//    var totalPages: Int {
//        menuItems.count
//    }
    
    var body: some View {
        ZStack {
            VStack {
                // 将 Label 放置在 VStack 的顶部
                Label("SelfMenu", systemImage: "book")
                    .font(.default)
                    .foregroundColor(.secondary)
                    .padding(8) // 添加一些内边距
                    .background(.thinMaterial) // 使用半透明材质帮助观察
                    .cornerRadius(8)
                
                Spacer() // 将 Label 顶到顶部
            }
            // 使用负数 offset 将整个 VStack 向上移动
            // 确保偏移量足够大，足以推入灵动岛/刘海下方
            .offset(y: -50) // *** 关键步骤：负数偏移量 ***
            .frame(maxWidth: .infinity, alignment: .top)
            
            VStack {
                Spacer()
                
                if !menuItems.isEmpty {
                    FlipCardView(currentIndex:$currentIndex)
                }
                
                Spacer()
                
                BottomSwitcher(currentIndex:$currentIndex, totalPages:$totalPages, isAddingMenu:$isAddingMenu)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            if initialSelfMenuItems {
                initialFirstSelfMenu()
            }
        }
        .onChange(of: menuItems) { oldValue, newValue in
            totalPages = newValue.count
        }
        .onChange(of: currentIndex) { oldValue, newValue in
            HapticManager.shared.lightImpact()
        }
    }
    
    private func initialFirstSelfMenu() {
        let initial1Item = MenuItems(
            MenuImageData: nil,
            MenuIndex: 0,
            MenuName: "Pizza",
            MenuMaterialNames: [
                "Pork",
                "Flour"
            ],
            MenuMaterialCounts: ["500g", "300g"],
            MenuMaterialComments: ["None", "None"],
            MenuSteps: ["Cook", "Bake"],
            MenuStepImageData:[nil, nil],
            Cookingtimes: 0,
            MeanCookingTime: 0
        )
        modelContext.insert(initial1Item)
        let initial2Item = MenuItems(
            MenuImageData: nil,
            MenuIndex: 1,
            MenuName: "Spaghetti",
            MenuMaterialNames: [
//                MaterialItem(name: "Spaghetti", count: "1 Bag", comment: ""),
//                MaterialItem(name: "Pork", count: "300g", comment: ""),
//                MaterialItem(name: "Sauce", count: "100g", comment: "")
                "Spaghetti",
                "Pork",
                "Sauce"
            ],
            MenuMaterialCounts: ["1Bags", "300g", "100g"],
            MenuMaterialComments: ["None", "None", "None"],
            MenuSteps: ["Boil", "Cook", "Stir"],
            MenuStepImageData:[nil, nil, nil],
            Cookingtimes: 0,
            MeanCookingTime: 0
        )
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
