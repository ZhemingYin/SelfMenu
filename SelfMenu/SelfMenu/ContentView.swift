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
import ActivityKit


struct ConditionalGlassEffect: ViewModifier {
    var strokeColor: Color = .red
    var overlayLineWidth: CGFloat = 12
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, visionOS 26.0, macOS 26.0, *) {
            content
                .glassEffect()
        } else {
            content
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        // 2. 在这里使用 strokeColor 变量
                        .stroke(strokeColor, lineWidth: overlayLineWidth)
                )
        }
    }
}

extension View {
    func conditionalGlassEffect(strokeColor: Color = .red, overlayLineWidth: CGFloat = 12) -> some View {
        modifier(ConditionalGlassEffect(strokeColor: strokeColor, overlayLineWidth: overlayLineWidth))
    }
}

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

struct CookingPersistence {
    static let menuIDKey = "CurrentCookingMenuID"
    static let startTimeKey = "CurrentCookingStartTime"
}

// MARK: - 卡片正面
struct CardFront: View {
    @Binding var currentIndex: Int
    @Binding var isEditingMenu: Bool
    
    var cardSize: CGSize
    
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
                
            VStack {
//                Spacer()
                if let imageData = currentMenuItem?.MenuImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
//                        .frame(width: 240, height: 350)
                        .frame(width: cardSize.width*0.9, height: cardSize.height*0.7)
                        .padding(.top, cardSize.width*0.05)
                        .clipShape(RoundedRectangle(cornerRadius: max(50 - cardSize.width * 0.05, 0)))
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
                        RoundedRectangle(cornerRadius: max(50 - cardSize.width * 0.05, 0))
                            .stroke(Color.secondary, style: StrokeStyle(lineWidth: 2, dash: [6]))
//                            .frame(width: 240, height: 350)
                            .frame(width: cardSize.width*0.9, height: cardSize.height*0.7)
                            .padding(.top, cardSize.width*0.05)
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
//                .padding(.bottom, 50)
                
                Spacer()
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
    @Binding var isEditingMenu: Bool
    
    var cardSize: CGSize
    
    @Environment(\.scenePhase) var scenePhase
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuItems.MenuIndex) private var menuItems: [MenuItems]
    private var currentMenuItem: MenuItems? {
        menuItems.first { $0.MenuIndex == currentIndex }
    }
    
    @State private var showStepPhotoPicker = false
    @State private var selectedStepPhotoItem: PhotosPickerItem? = nil
    @State private var targetStepIndex: Int? = nil
    @State private var activeAlarmIndex: Int? = nil
    
    // 计时器状态
    @State private var isCooking = false // 是否正在计时
    @State private var cookingStartTime: Date? = nil // 开始时间点
    @State private var elapsedSeconds: Int = 0 // 界面显示的流逝时间
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State private var currentActivity: Activity<CookingAttributes>? = nil
    
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
            
            ScrollView {
                
                VStack(alignment: .leading) {
                    if !isEditingMenu {
                        if let item = currentMenuItem {
                            HStack(spacing: 10) {
                                if !isCooking {
                                    Label("\(item.Cookingtimes)", systemImage: "flame.fill")
                                        .foregroundColor(.red)
                                    Label(formatTime(item.MeanCookingTime), systemImage: "clock.arrow.circlepath")
                                        .foregroundColor(.orange)
                                }
                                
                                Spacer()
                                
                                Button {
                                    if isCooking {
                                        finishCooking(for: item)
                                    } else {
                                        startCooking()
                                    }
                                } label: {
                                    HStack {
                                        Label({
                                            isCooking ? "Stop" : "Start"
                                        }(), systemImage: {
                                            isCooking ? "stop.fill" : "play"
                                        }())
                                        .bold()
                                        
                                        if isCooking {
                                            // 正在计时：显示动态时间
                                            Text(formatTime(elapsedSeconds))
                                                .contentTransition(.numericText())
                                                .padding(.leading, 2)
                                                .bold()
                                        }
                                    }
                                    .foregroundColor(isCooking ? .red : .blue)
                                }
                                .padding(10)
                                .buttonStyle(.plain)
                                .overlay(
                                    Capsule()
                                        .stroke(isCooking ? Color.red : Color.blue, lineWidth: 2)
                                        .padding(2)
                                )
                            }
                        }
                        
                        Divider()
                            .foregroundStyle(.blue)
                            .padding(.vertical, 5)
                    }
                    
                    if let item = currentMenuItem {
                        Text("Materials:")
                            .font(.title2)
                            .bold()
                            .padding(.bottom, 2)
                        
                        if isEditingMenu && item.MenuMaterialNames.isEmpty {
                            HStack(spacing: 10) {
                                Button {
                                    insertMaterialItem(at: 0, for: item)
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        
                        ForEach(item.MenuMaterialNames.indices, id: \.self) { index1 in
                            let name = item.MenuMaterialNames[index1]
                            let count = item.MenuMaterialCounts[index1]
                            let comment = item.MenuMaterialComments[index1]
                            
                            if !isEditingMenu {
                                HStack {
                                    Text("\(index1 + 1). ")
                                        .font(.title3)
                                        .foregroundColor(.primary)
                                        .bold()
                                    
                                    Text("\(name), ")
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
                                .padding(1)
                            } else {
                                VStack {
                                    HStack {
                                        Text("\(index1 + 1). ")
                                            .font(.footnote)
                                            .foregroundColor(.primary)
                                        Text("Name: ")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                        TextField("Name", text: Binding(
                                            get: {
                                                if index1 < item.MenuMaterialNames.count {
                                                    return item.MenuMaterialNames[index1]
                                                }
                                                return ""
                                            },
                                            set: { newValue in
                                                if index1 < item.MenuMaterialNames.count {
                                                    item.MenuMaterialNames[index1] = newValue.isEmpty ? "No Name" : newValue
                                                }
                                            }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                    
                                    HStack {
                                        Text("Count: ")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                        
                                        TextField("Count", text: Binding(
                                            get: {
                                                if index1 < item.MenuMaterialCounts.count {
                                                    return item.MenuMaterialCounts[index1]
                                                }
                                                return ""
                                            },
                                            set: { newValue in
                                                if index1 < item.MenuMaterialCounts.count {
                                                    item.MenuMaterialCounts[index1] = newValue.isEmpty ? "No Count" : newValue
                                                }
                                            }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                    
                                    HStack {
                                        Text("Comment (Optional): ")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                        
                                        TextField("Comment (Optional)", text: Binding(
                                            get: {
                                                if index1 < item.MenuMaterialComments.count {
                                                    return item.MenuMaterialComments[index1]
                                                }
                                                return ""
                                            },
                                            set: { newValue in
                                                if index1 < item.MenuMaterialComments.count {
                                                    item.MenuMaterialComments[index1] = newValue.isEmpty ? "None" : newValue
                                                }
                                            }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                    
                                    HStack(spacing: 10) {
                                        Button {
                                            insertMaterialItem(at: index1 + 1, for: item)
                                        } label: {
                                            Image(systemName: "plus.circle")
                                                .font(.title3)
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            deleteMaterialItem(at: index1, for: item)
                                        } label: {
                                            Image(systemName: "minus.circle")
                                                .font(.title3)
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Spacer()
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                
                    Divider()
                        .foregroundStyle(.blue)
                        .padding(.vertical, 5)
                    
                    if let item = currentMenuItem {
                        
                        Text("Steps:")
                            .font(.title2)
                            .bold()
                            .padding(.bottom, 2)
                        
                        if isEditingMenu && item.MenuSteps.isEmpty {
                            HStack(spacing: 10) {
                                Button {
                                    insertStepItem(at: 0, for: item)
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        
                        ForEach(item.MenuSteps.indices, id: \.self) { index2 in
                            let step = item.MenuSteps[index2]
                            let stepAlarm = (index2 < item.MenuStepAlarm.count) ? item.MenuStepAlarm[index2] : nil
                            let stepImageData = (index2 < item.MenuStepImageData.count) ? item.MenuStepImageData[index2] : nil
                            
                            if !isEditingMenu {
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("\(index2 + 1). ")
                                            .font(.title3)
                                            .foregroundColor(.primary)
                                        
                                        Text("\(step)")
                                            .font(.title3)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if let stepAlarm = stepAlarm, stepAlarm > 0 { // 只有非 nil 且大于 0 才显示
                                            Label("\(stepAlarm)m", systemImage: "timer")
                                                .padding(3)
                                                .background(Color.orange.opacity(0.1))
                                                .foregroundColor(.orange)
                                                .cornerRadius(8)
                                        }
                                        
                                    }
                                    .padding(1)
                                    
                                    if let data = stepImageData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFit()
                                            .cornerRadius(12)      // 圆角更美观
                                            .frame(maxWidth: .infinity) // 让图片居中
                                    }
                                }
                                
                            } else {
                                VStack {
                                    HStack {
                                        Text("\(index2 + 1). ")
                                            .font(.footnote)
                                            .foregroundColor(.primary)
                                        Text("Step: ")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                        TextField("Step", text: Binding(
                                            get: {
                                                if index2 < item.MenuSteps.count {
                                                    return item.MenuSteps[index2]
                                                }
                                                return ""
                                            },
                                            set: { newValue in
                                                if index2 < item.MenuSteps.count {
                                                    item.MenuSteps[index2] = newValue.isEmpty ? "No Name" : newValue
                                                }
                                            }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                    
                                    if let data = stepImageData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFit()
                                            .cornerRadius(12)      // 圆角更美观
                                            .frame(maxWidth: .infinity) // 让图片居中
                                            .onLongPressGesture(minimumDuration: 0.2) {
                                                if isEditingMenu {
                                                    targetStepIndex = index2
                                                    showStepPhotoPicker = true
                                                }
                                            }
                                    }
                                    
                                    HStack(spacing: 10) {
                                        Button {
                                            insertStepItem(at: index2 + 1, for: item)
                                        } label: {
                                            Image(systemName: "plus.circle")
                                                .font(.title3)
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            deleteStepItem(at: index2, for: item)
                                        } label: {
                                            Image(systemName: "minus.circle")
                                                .font(.title3)
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            targetStepIndex = index2
                                            showStepPhotoPicker = true
                                        } label: {
                                            Image(systemName: item.MenuStepImageData[index2] != nil ? "photo.fill" : "photo")
                                                .font(.title3)
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            activeAlarmIndex = index2
                                        } label: {
                                            let hasTime = (index2 < item.MenuStepAlarm.count && (item.MenuStepAlarm[index2] ?? 0) > 0)
                                            Image(systemName: hasTime ? "alarm.fill" : "alarm")
                                                .font(.title3)
                                                .foregroundColor(.orange)
                                        }
                                        .buttonStyle(.plain)
                                        .popover(isPresented: Binding<Bool>(
                                            get: {
                                                activeAlarmIndex == index2
                                            },
                                            set: { newValue in
                                                // 当弹窗关闭时 (newValue == false)，清空索引
                                                if !newValue { activeAlarmIndex = nil }
                                            }
                                        ), arrowEdge: .bottom) {
                                            VStack(spacing: 10) {
                                                Text("Timer")
                                                    .font(.headline)
                                                    .padding(.top, 10)
                                                
                                                Picker("Time", selection: Binding<Int>(
                                                    get: {
                                                        if index2 < item.MenuStepAlarm.count {
                                                            return item.MenuStepAlarm[index2] ?? 0
                                                        }
                                                        return 0
                                                    },
                                                    set: { newValue in
                                                        if index2 < item.MenuStepAlarm.count {
                                                            // 在主线程/动画块中更新 UI 绑定的数据
                                                            withAnimation {
                                                                let valueToSave: Int? = (newValue == 0 ? nil : newValue)
                                                                item.MenuStepAlarm[index2] = valueToSave
                                                            }
                                                        }
                                                    }
                                                )) {
                                                    Text("None").tag(0) // tag 类型必须是 Int
                                                    ForEach(1...180, id: \.self) { minute in
                                                        Text("\(minute) min").tag(minute)
                                                    }
                                                }
                                                .pickerStyle(.wheel)
                                                .frame(width: 200, height: 120) // 限制大小
                                            }
                                            // 5. 强制显示为小气泡
                                            .presentationCompactAdaptation(.popover)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            
                        }
                    } else {
                        Text("Can't find the corresponding materials")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(cardSize.width * 0.08)
        }
        .photosPicker(isPresented: $showStepPhotoPicker, selection: $selectedStepPhotoItem, matching: .images)
        .onChange(of: selectedStepPhotoItem) { oldItem, newItem in
            // 确保有点选 item 且知道是哪一行
            guard let newItem, let index = targetStepIndex, let item = currentMenuItem else { return }
            
            Task {
                // 异步加载图片数据
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    // 回到主线程更新 UI/数据
                    await MainActor.run {
                        // 安全检查防止数组越界（防止在打开Picker期间这行被删了）
                        if index < item.MenuStepImageData.count {
                            // 动画保存
                            withAnimation {
                                item.MenuStepImageData[index] = data
                            }
                        }
                    }
                }
                // 重置选中状态，以便下次可以选同一张图
                selectedStepPhotoItem = nil
                targetStepIndex = nil
            }
        }
        .onReceive(timer) { _ in
            // 只有在“正在烹饪”且“有开始时间”的情况下才更新
            if isCooking, let startTime = cookingStartTime {
                // 计算：当前时间 - 开始时间 = 经过的秒数
                elapsedSeconds = Int(Date().timeIntervalSince(startTime))
            }
        }
        // 监听来自灵动岛的关闭指令
        .onOpenURL { url in
            if url.absoluteString == "selfmenu://stopCooking" {
                // 如果收到停止指令，且当前正在烹饪，则结束
                if isCooking, let item = currentMenuItem {
                    print("Received stop command from Dynamic Island")
                    finishCooking(for: item)
                }
            }
        }
        .onAppear {
            restoreCookingState()
        }
        // 同时也建议监听 App 从后台回到前台的事件 (ScenePhase)，体验更丝滑
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                restoreCookingState()
            }
        }
    }
    
    private func insertMaterialItem(at index: Int, for item: MenuItems) {
        withAnimation {
            let safeIndex = min(index, item.MenuMaterialNames.count)
            
            item.MenuMaterialNames.insert("None", at: safeIndex)
            item.MenuMaterialCounts.insert("None", at: safeIndex)
            item.MenuMaterialComments.insert("None", at: safeIndex)
        }
    }

    private func deleteMaterialItem(at index: Int, for item: MenuItems) {
        withAnimation {
            // 只有当数组不为空且索引有效时才删除
            if index < item.MenuMaterialNames.count {
                item.MenuMaterialNames.remove(at: index)
                item.MenuMaterialCounts.remove(at: index)
                item.MenuMaterialComments.remove(at: index)
            }
        }
    }
    
    private func insertStepItem(at index: Int, for item: MenuItems) {
        withAnimation {
            let safeIndex = min(index, item.MenuSteps.count)
            
            item.MenuSteps.insert("None", at: safeIndex)
            item.MenuStepAlarm.insert(nil, at: safeIndex)
            item.MenuStepImageData.insert(nil, at: safeIndex)
        }
    }

    private func deleteStepItem(at index: Int, for item: MenuItems) {
        withAnimation {
            // 只有当数组不为空且索引有效时才删除
            if index < item.MenuSteps.count {
                item.MenuSteps.remove(at: index)
                item.MenuStepAlarm.remove(at: index)
                item.MenuStepImageData.remove(at: index)
            }
        }
    }
    
    private func startCooking() {
        isCooking = true
        cookingStartTime = Date()
        elapsedSeconds = 0
        
        if let item = currentMenuItem {
            UserDefaults.standard.set(item.id.uuidString, forKey: CookingPersistence.menuIDKey)
            UserDefaults.standard.set(cookingStartTime, forKey: CookingPersistence.startTimeKey)
        }
        
        // 检查设备是否支持
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are NOT enabled! Check Info.plist or Settings.")
            return
        }

        // 准备数据
        let attributes = CookingAttributes(totalTime: 0)
        let contentState = CookingAttributes.ContentState(
            startTime: Date(),
            menuName: currentMenuItem?.MenuName ?? "Food"
        )
        
        // 兼容 iOS 16.2+ 的写法
        let activityContent = ActivityContent(state: contentState, staleDate: nil)
        
        do {
            // 请求启动
            currentActivity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
            print("Success! Live Activity ID: \(currentActivity?.id ?? "Unknown")")
        } catch {
            // 这里会打印具体的报错原因
            print("Error starting Live Activity: \(error.localizedDescription)")
            print("Detailed Error: \(error)")
        }
    }

    // 2. 结束计时并保存数据
    private func finishCooking(for item: MenuItems) {
        guard let startTime = cookingStartTime else { return }
        
        let duration = Int(Date().timeIntervalSince(startTime))
        
        updateCookingStats(for: item, newDuration: duration)
        
        UserDefaults.standard.removeObject(forKey: CookingPersistence.menuIDKey)
        UserDefaults.standard.removeObject(forKey: CookingPersistence.startTimeKey)
        
        // 重置状态
        isCooking = false
        cookingStartTime = nil
        elapsedSeconds = 0
        currentActivity = nil
        
        Task {
            // 1. 定义结束时的显示状态 (比如显示 "Done!")
            let finalState = CookingAttributes.ContentState(
                startTime: Date(),
                menuName: "Done!"
            )
            
            let finalContent = ActivityContent(state: finalState, staleDate: nil)
            
            // 2. 【关键】不要只用 currentActivity?.end()
            // 而是遍历系统里属于这个 App 的所有活动，统统关掉。
            // 这样即使 App 重启过，currentActivity 是 nil，也能关掉灵动岛。
            for activity in Activity<CookingAttributes>.activities {
                print("Terminating activity: \(activity.id)")
                await activity.end(finalContent, dismissalPolicy: .immediate)
            }
            
            // 3. 置空本地变量
            await MainActor.run {
                self.currentActivity = nil
            }
        }
    }

    // 3. 核心算法：更新平均时间和次数
    private func updateCookingStats(for item: MenuItems, newDuration: Int) {
        let oldTotalTime = item.MeanCookingTime * item.Cookingtimes
        
        item.Cookingtimes += 1
        
        let newTotalTime = oldTotalTime + newDuration
        item.MeanCookingTime = newTotalTime / item.Cookingtimes
        
    }

    // 4. 格式化时间显示 (秒 -> MM:SS 或 HH:MM:SS)
    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func restoreCookingState() {
        // 检查是否有SelfMenu正在进行的 Live Activity
        let activeActivities = Activity<CookingAttributes>.activities
        
        // 如果系统里没有任何活动在跑，说明可能已经结束了，或者用户在锁屏上划掉了
        guard let activity = activeActivities.first else {
            // 双重保险：如果系统里没活动，但 UserDefaults 里还有脏数据，顺便清理掉
            UserDefaults.standard.removeObject(forKey: CookingPersistence.menuIDKey)
            UserDefaults.standard.removeObject(forKey: CookingPersistence.startTimeKey)
            isCooking = false
            cookingStartTime = nil
            elapsedSeconds = 0
            currentActivity = nil
            return
        }
        
        // 2. 重新绑定 Activity 实例
        // 这样点击 "Stop Cooking" 才能控制这个“死而复生”的活动
        self.currentActivity = activity
        
        // 3. 恢复数据状态
        if let savedStartTime = UserDefaults.standard.object(forKey: CookingPersistence.startTimeKey) as? Date,
           let savedMenuIDString = UserDefaults.standard.string(forKey: CookingPersistence.menuIDKey),
           let item = currentMenuItem { // 确保当前卡片就是正在做的那个菜
            
            // 只有当保存 ID 等于当前卡片 ID 时才恢复界面
            // (防止你在做 Pizza，结果滑到了 Pasta 的卡片，Pasta 却显示正在做)
            if item.id.uuidString == savedMenuIDString {
                self.cookingStartTime = savedStartTime
                self.isCooking = true
                self.elapsedSeconds = Int(Date().timeIntervalSince(savedStartTime))
                print("Restored cooking session from disk")
            }
        }
    }
}


struct FlipCardView:View {
    @Binding var currentIndex: Int
    
    var cardSize: CGSize
    
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
    @Binding var isEditingMenu:Bool
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
                            .conditionalGlassEffect(strokeColor: .red, overlayLineWidth: 12)
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
                                .conditionalGlassEffect(strokeColor: .blue, overlayLineWidth: 12)
                                .opacity(min(max(verticalOffset / 120, 0), 1))
                                .scaleEffect(0.8 + 0.2 * min(max(verticalOffset / 120, 0), 1))
                                .scaleEffect(isEditingMenu ? 1.3 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.4), value: isEditingMenu)
                        }
                        .padding(.top, 20)
                    } else {
                        Button {
                            isEditingMenu = false
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                baseVerticalOffset = 0
                                verticalOffset = 0
                                baseHorizontalOffset = 0
                                horizontalOffset = 0
                                isEditingMenu = false
                            }
                        } label: {
                            VStack {
                                Label("Done", systemImage: "checkmark")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .background(Color.clear)
                                    .padding()
                                    .conditionalGlassEffect(strokeColor: .blue, overlayLineWidth: 12)
                                    .opacity(min(max(verticalOffset / 120, 0), 1))
                                    .scaleEffect(0.8 + 0.2 * min(max(verticalOffset / 120, 0), 1))
                                
                                Label("Long tap to edit the photo.", systemImage: "lightbulb")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .background(Color.clear)
                                    .opacity(min(max(verticalOffset / 120, 0), 1))
                            }
                        }
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                }
            }
            
            ZStack {
                // 卡片正面
                CardFront(currentIndex:$currentIndex, isEditingMenu:$isEditingMenu, cardSize:cardSize)
                    .opacity(flipped ? 0 : 1)
                    .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))

                // 卡片背面
                CardBack(currentIndex:$currentIndex, isEditingMenu:$isEditingMenu, cardSize:cardSize)
                    .opacity(flipped ? 1 : 0)
                    .rotation3DEffect(.degrees(rotation + 180), axis: (x: 0, y: 1, z: 0))
            }
            .shadow(color: Color.primary.opacity(0.3), radius: 20, x: 0, y: 0)
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
                                baseHorizontalOffset = 0
                                horizontalOffset = 0
                            }
                            HapticManager.shared.lightImpact()
                            isEditingMenu = false
                        }
                        
                        // ---- 向上滑更远 —— Delete ----
                        else if verticalOffset < -220 {
                            deletePulse = true
                            withAnimation(.easeOut(duration: 0.25)) {
                                baseVerticalOffset = -1000
                                verticalOffset = -1000
                                baseHorizontalOffset = 0
                                horizontalOffset = 0
                            }
                            
                            isEditingMenu = false

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
                        else if verticalOffset > 130 && verticalOffset < 180 {
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
                        else if verticalOffset > 180 {
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
                            isEditingMenu = false
                        }
                        
                        // ---- 向左滑 —— 下一页 ----
                        else if horizontalOffset < -120 && currentIndex < menuItems.count-1 {
                            // 向左滑动，下一页
                            currentIndex += 1
                            isEditingMenu = false
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
        .frame(width: cardSize.width, height: cardSize.height)
//        .frame(width: 360, height: 600)
//        .frame(width: 600, height: 800)
        .background(Color.clear)
        .onChange(of: currentIndex) { oldValue, newValue in
            let direction: CGFloat = newValue > oldValue ? 1 : -1
            
            // 新卡片先从屏幕侧面开始
//            horizontalOffset = 400 * direction
            horizontalOffset = (cardSize.width * 1.5) * direction
            
            // 重置翻转状态
            flipped = false
            isEditingMenu = false
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
            .padding(.leading, 10)
            .disabled(true) // 禁用点击
            .allowsHitTesting(false) // 禁止触摸事件
            
            Spacer()
            
            if !menuItems.isEmpty {
                PageControl(currentPage: $currentIndex, numberOfPages: menuItems.count)
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
                        MenuStepAlarm: [],
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
//                    .frame(width: 44, height: 44)
                    .padding(.horizontal, 1)
            }
            .frame(width: 44, height: 44)
            .buttonStyle(PlainButtonStyle())
            .background(.clear)
            .conditionalGlassEffect(strokeColor: .blue, overlayLineWidth: 12)
            .padding(.trailing, 10)
            
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
//    @State private var initialSelfMenuItems = true
    @AppStorage("initialSelfMenuItems") private var initialSelfMenuItems = true
    @State private var currentIndex: Int = 0
//    @State private var totalPages: Int = 0
    
    @State private var isAddingMenu: Bool = false
    @State private var isEditingMenu = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuItems.MenuIndex) private var menuItems: [MenuItems]
//    var totalPages: Int {
//        menuItems.count
//    }
    
    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width * 0.8
            let cardHeight = geometry.size.height * 0.7
            let cardSize = CGSize(width: cardWidth, height: cardHeight)
            
            ZStack {
                VStack {
                    // 将 Label 放置在 VStack 的顶部
                    Label("SelfMenu", systemImage: "book")
                        .font(.footnote)
                        .foregroundColor(.orange)
                        .padding(8) // 添加一些内边距
//                        .background(.thinMaterial) // 使用半透明材质帮助观察
                        .cornerRadius(8)
                        .overlay(
                            Capsule()
                                .stroke(Color.orange, lineWidth: 2)
                                .padding(2)
                        )
                    
                    Spacer() // 将 Label 顶到顶部
                }
                // 使用负数 offset 将整个 VStack 向上移动
                .offset(y: 20)
                .frame(maxWidth: .infinity, alignment: .top)
                
                VStack {
                    Spacer()
                    
                    if !menuItems.isEmpty {
                        FlipCardView(currentIndex:$currentIndex, cardSize:cardSize, isEditingMenu:$isEditingMenu)
                            .padding(.top, geometry.size.height*0.02)
                            .frame(width: cardWidth, height: cardHeight)
                    }
                    
                    Spacer()
                    
                    if !isEditingMenu {
                        BottomSwitcher(currentIndex:$currentIndex, isAddingMenu:$isAddingMenu)
                            .padding(.trailing, geometry.size.width*0.01)
                            .padding(.bottom, geometry.size.height*0.03)
                    } else {
                        Button(action: {}) {
                            Image(systemName: "list.bullet")
                                .font(.body.weight(.medium))
                                .foregroundColor(.clear) // 完全透明
                                .frame(width: 44, height: 44)
                                .background(Color.clear) // 透明背景
                                .clipShape(Circle())
                        }
                        .padding(.trailing, geometry.size.width*0.01)
                        .padding(.bottom, geometry.size.height*0.03)
                        .disabled(true) // 禁用点击
                        .allowsHitTesting(false) // 禁止触摸事件
                    }
                    
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea(.container, edges: .all)
        .onAppear {
            if initialSelfMenuItems {
                initialFirstSelfMenu()
            }
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
            MenuStepAlarm: [5, nil],
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
            MenuStepAlarm: [nil, 5, nil],
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
