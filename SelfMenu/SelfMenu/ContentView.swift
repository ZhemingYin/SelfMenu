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
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif
import CryptoKit // 用于生成确定性 UUID


extension UIDevice {
    /// 判断是否是灵动岛机型
    /// 灵动岛机型的顶部安全区域通常 >= 59
    /// 刘海屏通常在 44-48 之间，旧机型更小
    static var hasDynamicIsland: Bool {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })
        else {
            return false
        }
        // 51 是一个安全阈值，灵动岛通常是 59
        return window.safeAreaInsets.top >= 50
    }
}

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

nonisolated struct CookingAlarmMetaData: AlarmMetadata {}

extension UUID {
    /// 根据字符串生成一个固定的 UUID
    /// 只要输入字符串相同，返回的 UUID 永远相同
    static func from(string: String) -> UUID {
        // 1. 将字符串转为 Data
        let inputData = Data(string.utf8)
        
        // 2. 使用 SHA256 哈希算法（生成 32 字节的数据）
        let hashed = SHA256.hash(data: inputData)
        
        // 3. 截取前 16 个字节来构建 UUID
        // (UUID 固定长度为 16 字节 / 128 位)
        var uuidBytes = (
            UInt8(0), UInt8(0), UInt8(0), UInt8(0),
            UInt8(0), UInt8(0), UInt8(0), UInt8(0),
            UInt8(0), UInt8(0), UInt8(0), UInt8(0),
            UInt8(0), UInt8(0), UInt8(0), UInt8(0)
        )
        
        // 将 Hash 的前 16 位复制到 tuple 中
        // 这是一个比较底层的内存操作，但在 Swift 中是安全的
        hashed.withUnsafeBytes { buffer in
            guard buffer.count >= 16 else { return }
            let ptr = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            uuidBytes.0 = ptr[0];  uuidBytes.1 = ptr[1];  uuidBytes.2 = ptr[2];  uuidBytes.3 = ptr[3]
            uuidBytes.4 = ptr[4];  uuidBytes.5 = ptr[5];  uuidBytes.6 = ptr[6];  uuidBytes.7 = ptr[7]
            uuidBytes.8 = ptr[8];  uuidBytes.9 = ptr[9];  uuidBytes.10 = ptr[10]; uuidBytes.11 = ptr[11]
            uuidBytes.12 = ptr[12]; uuidBytes.13 = ptr[13]; uuidBytes.14 = ptr[14]; uuidBytes.15 = ptr[15]
        }
        
        return UUID(uuid: uuidBytes)
    }
}

class CookingActivityManager {
    static let shared = CookingActivityManager()
    
    // 开启一个新的烹饪活动
    func startCooking(menuName: String, menuID: UUID, totalTime: Int) {
        // 检查是否已有这个ID在跑
        if isCooking(menuID: menuID) { return }
        
        let attributes = CookingAttributes(totalTime: totalTime)
        let contentState = CookingAttributes.ContentState(
            startTime: Date(),
            menuName: menuName,
            menuID: menuID
        )
        
        let activityContent = ActivityContent(state: contentState, staleDate: nil)
        
        do {
            let _ = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
        } catch {
            print("Error starting activity: \(error.localizedDescription)")
        }
    }
    
    func stopCooking(menuID: UUID) async {
        for activity in Activity<CookingAttributes>.activities {
            if activity.content.state.menuID == menuID {
                
                let finalState = CookingAttributes.ContentState(
                    startTime: activity.content.state.startTime,
                    menuName: "Done!" as String,
                    menuID: menuID
                )
                
                let finalContent = ActivityContent(state: finalState, staleDate: nil)
                
                await activity.end(finalContent, dismissalPolicy: .immediate)
                print("Stopped activity for menuID: \(menuID)")
            }
        }
    }
    
    func isCooking(menuID: UUID) -> Bool {
        return getActivity(for: menuID) != nil
    }
    
    // 获取某个菜对应的 Activity 对象（用于获取开始时间）
    func getActivity(for menuID: UUID) -> Activity<CookingAttributes>? {
        return Activity<CookingAttributes>.activities.first {
            $0.content.state.menuID == menuID
        }
    }
}

struct ImageEditorView: View {
    var originalImage: UIImage
    var onSave: (UIImage) -> Void // 保存回调
    var onCancel: () -> Void      // 取消回调
    
    @State private var displayImage: UIImage
    
    init(image: UIImage, onSave: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.originalImage = image
        _displayImage = State(initialValue: image)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // 如果有编辑逻辑，这里传回编辑后的图片
                        onSave(displayImage)
                    }
                }
            }
            .background(Color.white.ignoresSafeArea()) // 编辑页面通常用黑色背景
        }
    }
}

struct StepTimerButton: View {
    let minutes: Int
    // 传入唯一的通知 ID，用于去系统查询
    let timerID: String
    // 传入点击后的回调函数，用于触发和取消系统通知
    let onStart: () -> Void
    let onCancel: () -> Void
    
    // 内部状态：记录倒计时结束时间
    @State private var targetTime: Date? = nil
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // 计算属性：判断是否正在倒计时
    private var isRunning: Bool {
        // 只有当目标时间存在，且目标时间在当前时间之后（还没过期）时，才算正在运行
        guard let target = targetTime else { return false }
        return target > Date()
    }
    
    var body: some View {
        Button {
            if isRunning {
                // 如果正在跑，再次点击则取消/重置
                withAnimation {
                    targetTime = nil
                }
                onCancel()
            } else {
                // 设置结束时间
                targetTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
                onStart()
            }
            HapticManager.shared.lightImpact()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                
                if let target = targetTime {
                    Text(target, style: .timer)
                } else {
                    Text("\(minutes)m")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(isRunning ? .red : .orange)
            .cornerRadius(8)
            .overlay(
                Capsule()
                    .stroke(isRunning ? Color.red.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onReceive(timer) { _ in
            guard let target = targetTime else { return }
            
            // 如果当前时间已经晚于目标时间（说明倒计时结束了）
            if Date() >= target {
                withAnimation {
                    self.targetTime = nil
                }
            }
        }
        // 视图出现时，检查系统通知中心
        .task {
            await checkSystemNotificationStatus()
        }
        // 监听 App 从后台回到前台，再次检查（防止时间误差）
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await checkSystemNotificationStatus() }
        }
    }
    
    private func checkSystemNotificationStatus() async {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        
        // 在所有等待发送的通知里，找指定ID
        if let request = requests.first(where: { $0.identifier == timerID }) {
            
            var triggerDate: Date? = nil
            
            if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
                triggerDate = calendarTrigger.nextTriggerDate()
            }
            
            // 如果找到了，说明系统正在倒计时
            // 把系统的触发时间同步给 UI
            if let nextFireDate = triggerDate {
                await MainActor.run {
                    if nextFireDate > Date() {
                        // 找到了未来的时间点，直接赋值，倒计时会自动计算差值
                        self.targetTime = nextFireDate
                    } else {
                        self.targetTime = nil
                    }
                }
                return
            }
        } else {
            // 如果系统里没有这个通知（可能时间到了已经发完了），重置 UI
            await MainActor.run {
                self.targetTime = nil
            }
        }
    }
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
    @State private var newMenuNameComment: String = ""
    @State private var selectedImageItem: PhotosPickerItem? = nil
    @State private var showingPhotoPicker: Bool = false
    @State private var showingImageEditor = false
    @State private var tempSelectedImage: UIImage? = nil
    
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
                        updateCardFrontName()
                    }
                    .disabled(!isEditingMenu)
                    Spacer()
                }
//                .padding(.bottom, 50)
                
                if !newMenuNameComment.isEmpty || isEditingMenu {
                    HStack {
                        Spacer()
                        TextField(
                            "Comment (Optional)",
                            text: $newMenuNameComment,
                        )
                        .fixedSize()
                        .frame(minWidth: 50)
                        .foregroundStyle(.secondary)
                        .bold()
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit {
                            updateCardFrontNameComment()
                        }
                        .disabled(!isEditingMenu)
                        Spacer()
                    }
                }
                
                Spacer()
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedImageItem)
        .onChange(of: selectedImageItem) { _, newItem in
            guard let newItem else { return }
            Task {
                // 异步加载图片数据
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    // 放到主线程更新 UI
                    await MainActor.run {
                        self.tempSelectedImage = uiImage // 暂存图片
                        self.showingImageEditor = true   // 打开编辑页面
                        self.selectedImageItem = nil     // 重置选择器以便下次触发
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingImageEditor) {
            if let img = tempSelectedImage {
                // 使用我们刚写的 UIKit 桥接器
                AnalysisEditorWrapper(
                    image: img,
                    onSave: { editedImage in
                        // 1. 保存图片逻辑
                        saveImageToModel(editedImage)
                        // 2. 关闭页面
                        showingImageEditor = false
                    },
                    onCancel: {
                        // 取消逻辑
                        showingImageEditor = false
                        tempSelectedImage = nil
                    }
                )
                .ignoresSafeArea() // 确保全屏显示
            } else {
                // 异常处理：加载中或无图
                ProgressView()
                    .onAppear { showingImageEditor = false }
            }
        }
//        .onChange(of: selectedImageItem) { _, newItem in
//            guard let newItem else { return }
//            Task {
//                if let data = try? await newItem.loadTransferable(type: Data.self) {
//                    if let item = currentMenuItem {
//                        item.MenuImageData = data
//                        try? modelContext.save()
//                    }
//                }
//            }
//        }
        .onAppear {
            newMenuName = currentMenuItem?.MenuName ?? "New Menu"
            newMenuNameComment = currentMenuItem?.MenuNameComment ?? ""
        }
        .onChange(of: currentIndex) { oldValue, newValue in
            newMenuName = currentMenuItem?.MenuName ?? "New Menu"
            newMenuNameComment = currentMenuItem?.MenuNameComment ?? ""
        }
        .onChange(of: menuItems) { oldValue, newValue in
            newMenuName = currentMenuItem?.MenuName ?? "New Menu"
            newMenuNameComment = currentMenuItem?.MenuNameComment ?? ""
        }
    }
    
    private func saveImageToModel(_ image: UIImage) {
        guard let imageData = image.pngData() else { return }
        
        if let item = currentMenuItem {
            item.MenuImageData = imageData
            do {
                try modelContext.save()
                print("Image updated successfully")
            } catch {
                print("Failed to save image: \(error)")
            }
        }
    }
    
    private func updateCardFrontName() {
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
    
    private func updateCardFrontNameComment() {
        if let updateCardFrontItem = menuItems.first(
            where: { $0.MenuIndex == currentIndex})
        {
            updateCardFrontItem.MenuNameComment = newMenuNameComment
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
    @State private var localIsCooking = false
    @State private var localElapsedSeconds: Int = 0
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
//    @State private var currentActivity: Activity<CookingAttributes>? = nil
    
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
                                if !localIsCooking {
                                    Label("\(item.Cookingtimes)", systemImage: "flame.fill")
                                        .foregroundColor(.red)
                                    Label(formatTime(item.MeanCookingTime), systemImage: "clock.arrow.circlepath")
                                        .foregroundColor(.orange)
                                }
                                
                                Spacer()
                                
                                Button {
                                    handleButtonPress(for: item)
                                    HapticManager.shared.lightImpact()
                                } label: {
                                    HStack {
                                        Label({
                                            localIsCooking ? "Stop" : "Start"
                                        }(), systemImage: {
                                            localIsCooking ? "stop.fill" : "play"
                                        }())
                                        .bold()
                                        
                                        if localIsCooking {
                                            // 正在计时：显示动态时间
                                            Text(formatTime(localElapsedSeconds))
                                                .contentTransition(.numericText())
                                                .padding(.leading, 2)
                                                .bold()
                                        }
                                    }
                                    .foregroundColor(localIsCooking ? .red : .blue)
                                }
                                .padding(10)
                                .buttonStyle(.plain)
                                .overlay(
                                    Capsule()
                                        .stroke(localIsCooking ? Color.red : Color.blue, lineWidth: 2)
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
                                    HapticManager.shared.lightImpact()
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
                                            HapticManager.shared.lightImpact()
                                        } label: {
                                            Image(systemName: "plus.circle")
                                                .font(.title3)
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            deleteMaterialItem(at: index1, for: item)
                                            HapticManager.shared.lightImpact()
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
                                    HapticManager.shared.lightImpact()
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
                                        
                                        // MARK: - 闹钟按钮
                                        if let stepAlarm = stepAlarm, stepAlarm > 0 {
                                            let timerID = getNotificationID(menuName: item.MenuName, menuID: item.id, stepIndex: index2)
                                            StepTimerButton(
                                                minutes: stepAlarm,
                                                timerID: timerID,
                                                onStart: {
                                                    startStepTimer(
                                                        minutes: stepAlarm,
                                                        stepIndex: index2,
                                                        stepContent: step,
                                                        menuName: item.MenuName,
                                                        menuID: item.id
                                                    )
                                                },
                                                onCancel: {
                                                    cancelStepTimer(
                                                        stepIndex: index2,
                                                        menuName: item.MenuName,
                                                        menuID: item.id
                                                    )
                                                }
                                            )
                                            .padding(.top, 4)
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
                                            HapticManager.shared.lightImpact()
                                        } label: {
                                            Image(systemName: "plus.circle")
                                                .font(.title3)
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            deleteStepItem(at: index2, for: item)
                                            HapticManager.shared.lightImpact()
                                        } label: {
                                            Image(systemName: "minus.circle")
                                                .font(.title3)
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            targetStepIndex = index2
                                            showStepPhotoPicker = true
                                            HapticManager.shared.lightImpact()
                                        } label: {
                                            Image(systemName: item.MenuStepImageData[index2] != nil ? "photo.fill" : "photo")
                                                .font(.title3)
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            activeAlarmIndex = index2
                                            HapticManager.shared.lightImpact()
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
            // 监听定时器，更新当前卡片的状态
            updateLocalState()
        }
        // 监听来自灵动岛的关闭指令
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onAppear {
            updateLocalState()
        }
        // 同时也建议监听 App 从后台回到前台的事件 (ScenePhase)，体验更丝滑
        .onChange(of: scenePhase) { oldPhase, newPhase in
            updateLocalState()
        }
        .onChange(of: currentIndex) { oldIndex, newIndex in
            updateLocalState()
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
    
    private func handleButtonPress(for item: MenuItems) {
        if localIsCooking {
            // 正在做 -> 停止
            Task {
                await CookingActivityManager.shared.stopCooking(menuID: item.id)
                // 更新统计数据逻辑...
                updateCookingStats(for: item, newDuration: localElapsedSeconds)
                // 强制刷新一下UI
                await MainActor.run { updateLocalState() }
            }
        } else {
            // 没在做 -> 开始
            CookingActivityManager.shared.startCooking(
                menuName: item.MenuName,
                menuID: item.id,
                totalTime: 0
            )
            // 强制刷新一下UI
            updateLocalState()
        }
    }
    
    // 刷新逻辑，这个函数每一秒都会跑一次，去询问 Manager：“当前这个菜，正在做吗？”
    private func updateLocalState() {
        guard let item = currentMenuItem else { return }
        
        // 去 Manager 查，是否有针对当前 Item ID 的活动
        if let activity = CookingActivityManager.shared.getActivity(for: item.id) {
            // 找到了！说明正在做
            self.localIsCooking = true
            let startTime = activity.content.state.startTime
            self.localElapsedSeconds = Int(Date().timeIntervalSince(startTime))
        } else {
            // 没找到，说明没在做
            self.localIsCooking = false
            self.localElapsedSeconds = 0
        }
    }
    
    // 处理 URL Scheme
    private func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.host == "stopCooking" else { return }
        
        // 从 URL 参数中解析 menuID
        // 格式: selfmenu://stopCooking?menuID=xxxxx-xxxx...
        if let queryItems = components.queryItems,
           let idString = queryItems.first(where: { $0.name == "menuID" })?.value,
           let uuid = UUID(uuidString: idString) {
            
            print("Received stop command for ID: \(uuid)")
            
            Task {
                // 停止活动
                await CookingActivityManager.shared.stopCooking(menuID: uuid)
                
                // 如果当前正好显示的是这个菜，更新统计数据
                if let currentItem = currentMenuItem, currentItem.id == uuid {
                    // 这里可能需要算出时长，但活动已经结束了，可以拿当前时间 - 开始时间
                    // 或者简单处理，等 updateLocalState 自动归零
                    await MainActor.run {
                        updateLocalState()
                        updateCookingStats(for: currentItem, newDuration: localElapsedSeconds)
                    }
                }
            }
        }
    }

    // 更新平均时间和次数
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
    
    private func getNotificationID(menuName: String, menuID: UUID, stepIndex: Int) -> String {
        let cleanName = menuName.replacingOccurrences(of: " ", with: "_")
        return "SelfMenu_\(cleanName)_\(menuID.uuidString)_Step_\(stepIndex)"
    }
    
    private func getAlarmLabel(menuName: String, menuID: UUID, stepIndex: Int) -> String {
        let cleanName = menuName.replacingOccurrences(of: " ", with: "_")
        return "SelfMenu-\(cleanName)-\(menuID.uuidString)-Step-\(stepIndex)-Alarm"
    }
    
    private func startStepTimer(minutes: Int, stepIndex: Int, stepContent: String, menuName: String, menuID: UUID) {
        let targetDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        let alarmLabel = getAlarmLabel(menuName: menuName, menuID: menuID, stepIndex: stepIndex)
        let alarmLabelUUID = UUID.from(string: alarmLabel)
        
        // AlarmKit
        if #available(iOS 26.0, *) {
            Task {
                do {
                    // 获取授权状态
                    var status = AlarmManager.shared.authorizationState
                    if status == .notDetermined {
                        // 请求授权
                        status = try await AlarmManager.shared.requestAuthorization()
                    }
                    
                    if status == .authorized {
//                        let schedule = Alarm.Schedule.fixed(targetDate)
                        
                        let stopButton = AlarmButton(
                            text: "Done",
                            textColor: .orange,
                            systemImageName: "stop.circle"
                        )
                        
                        let alertPresentation = AlarmPresentation.Alert(
                            title: "\(menuName): Step \(stepIndex + 1) Ready!",
                            stopButton: stopButton
                        )
                        
                        let attributes = AlarmAttributes<CookingAlarmMetaData>(
                            presentation:AlarmPresentation(alert: alertPresentation),
                            tintColor: Color.orange
                        )
                        
//                        let alarmConfiguration = AlarmManager.AlarmConfiguration<CookingAlarmMetaData>(
//                            schedule: schedule,
//                            attributes: attributes,
//                            sound: .default)
                        
//                        let _ = try await AlarmManager.shared.schedule(id: alarmLabelUUID, configuration: alarmConfiguration)
                        let timerAlarm = try await AlarmManager.shared.schedule(
                            id: alarmLabelUUID,
                            configuration: .timer(
                                duration: TimeInterval(minutes * 60),
                                attributes: attributes
                            )
                        )
                    }
                } catch {
                    print("AlarmKit error: \(error)")
                }
            }
        }
        
        // The normal notification
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = "\(menuName): Step \(stepIndex + 1) Timer Done! 🍳"
                content.body = stepContent
                content.sound = .default
                
                let targetDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
                let dateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: targetDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                
                let id = getNotificationID(menuName: menuName, menuID: menuID, stepIndex: stepIndex)
                
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                
                center.add(request) { error in
                    if let error = error {
                        print("Error scheduling notification: \(error)")
                    }
                }
            } else {
                print("Notification permission denied")
            }
        }
    }
    
    private func cancelStepTimer(stepIndex: Int, menuName: String, menuID: UUID) {
        let center = UNUserNotificationCenter.current()
        
        let id = getNotificationID(menuName: menuName, menuID: menuID, stepIndex: stepIndex)
        let alarmLabel = getAlarmLabel(menuName: menuName, menuID: menuID, stepIndex: stepIndex)
        let alarmLabelUUID = UUID.from(string: alarmLabel)
        
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
        
        if #available(iOS 26.0, *) {
            #if canImport(AlarmKit)
            Task {
                do {
                    try AlarmManager.shared.cancel(id: alarmLabelUUID)
                } catch {
                    print("AlarmKit error: \(error)")
                }
            }
            #endif
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
                        HapticManager.shared.lightImpact()
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
                            HapticManager.shared.lightImpact()
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
                            HapticManager.shared.lightImpact()
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
                HapticManager.shared.lightImpact()
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
                        MenuNameComment: nil,
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
                    Label("SelfMenus", systemImage: "book")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .padding(5) // 添加一些内边距
//                        .background(.thinMaterial) // 使用半透明材质帮助观察
                        .cornerRadius(8)
                        .overlay(
                            Capsule()
                                .stroke(Color.orange, lineWidth: 2)
                                .padding(2)
                        )
                    
                    Spacer() // 将 Label 顶到顶部
                }
                .offset(y: UIDevice.hasDynamicIsland ? 18 : 3)
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
            MenuNameComment: nil,
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
            MenuNameComment: nil,
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
