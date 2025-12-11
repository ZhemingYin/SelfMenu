//
//  ImageProcessor.swift
//  SelfMenu
//
//  Created by 尹哲铭 on 11.12.25.
//


import SwiftUI
import UIKit
import Vision
import VisionKit

// MARK: - 1. UIKit 控制器
class AnalysisViewController: UIViewController {

    var imageToEdit: UIImage?
    var onSave: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?

    private var imageView: UIImageView!
    private var interaction: ImageAnalysisInteraction!
    private let analyzer = ImageAnalyzer()
    
    // 加载指示器
    private let loadingOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.isHidden = true
        view.isUserInteractionEnabled = true
        
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        return view
    }()
    
    // 提示标签
    private let hintLabel: UILabel = {
        let label = UILabel()
        label.text = "点击主体可去背景，或点 Done 保存"
        label.textColor = .white.withAlphaComponent(0.9)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
        label.layer.cornerRadius = 20
        label.layer.masksToBounds = true
        label.textAlignment = .center
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupImageView()
        setupNavigationBar()
        setupGestures()
        
        // 布局 Loading
        loadingOverlay.frame = view.bounds
        loadingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(loadingOverlay)
        
        // 布局提示标签
        view.addSubview(hintLabel)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            hintLabel.widthAnchor.constraint(equalToConstant: 280),
            hintLabel.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        Task {
            await initAnalysis()
        }
    }

    private func setupImageView() {
        imageView = UIImageView(frame: view.bounds)
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        
        if let img = imageToEdit {
            imageView.image = img
        }
        view.addSubview(imageView)
    }

    private func setupNavigationBar() {
        // 左侧：Cancel
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        let doneItem = UIBarButtonItem(title: "Done", style: .prominent, target: self, action: #selector(saveTapped))
        doneItem.setTitleTextAttributes([.font: UIFont.boldSystemFont(ofSize: 17)], for: .normal)
        
        navigationItem.rightBarButtonItem = doneItem
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleImageTap))
        imageView.addGestureRecognizer(tapGesture)
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    // Done 按钮响应
    @objc private func saveTapped() {
        // 用户不想抠图，直接保存当前图片
        if let currentImage = imageView.image {
            onSave?(currentImage)
        }
    }

    // MARK: - ✨ 路径 A：点击图片 -> 自动抠图 -> 自动保存
    @objc private func handleImageTap() {
        guard let currentImage = imageView.image else { return }
        
        loadingOverlay.isHidden = false
        hintLabel.isHidden = true
        
        Task {
            if let croppedImage = await performSubjectLifting(on: currentImage) {
                // 成功
                await MainActor.run {
                    onSave?(croppedImage)
                }
            } else {
                // 失败
                await MainActor.run {
                    loadingOverlay.isHidden = true
                    hintLabel.isHidden = false
                    hintLabel.text = "未识别到主体，请重试或点 Done"
                    hintLabel.backgroundColor = UIColor.red.withAlphaComponent(0.6)
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.hintLabel.text = "点击主体可去背景，或点 Done 保存"
                        self.hintLabel.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
                    }
                }
            }
        }
    }

    // MARK: - Vision 抠图算法
    private func performSubjectLifting(on image: UIImage) async -> UIImage? {
        guard #available(iOS 17.0, *), let cgImage = image.cgImage else { return nil }

        return await Task.detached(priority: .userInitiated) { () -> UIImage? in
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage)
            
            do {
                try handler.perform([request])
                guard let result = request.results?.first else { return nil }
                
                let pixelBuffer = try result.generateMaskedImage(
                    ofInstances: result.allInstances,
                    from: handler,
                    croppedToInstancesExtent: true
                )
                
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                let context = CIContext()
                if let newCgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    return UIImage(cgImage: newCgImage)
                }
            } catch {
                print("抠图失败: \(error)")
                return nil
            }
            return nil
        }.value
    }

    // MARK: - VisionKit 交互
    func initAnalysis() async {
        guard let image = imageView.image else { return }
        
        if interaction != nil {
            imageView.removeInteraction(interaction)
        }
        
        interaction = ImageAnalysisInteraction()
        imageView.addInteraction(interaction)

        let configuration = ImageAnalyzer.Configuration([.visualLookUp])

        do {
            let analysis = try await analyzer.analyze(image, configuration: configuration)
            
            await MainActor.run {
                interaction.analysis = analysis
                interaction.preferredInteractionTypes = [.imageSubject]
                
//                if #available(iOS 17.0, *) {
//                    interaction.preferredInteractionTypes = [.imageSubject]
//                    
//                    if !analysis.hasResults(for: .visualLookUp) {
//                        hintLabel.text = "无主体，请点 Done 保存"
//                    }
//                } else {
//                    interaction.preferredInteractionTypes = .automatic
//                }
            }
        } catch {
            print("分析失败: \(error)")
        }
    }
}



//import SwiftUI
//import UIKit
//import Vision
//import VisionKit
//
//// MARK: - 1. UIKit 控制器
//class AnalysisViewController: UIViewController {
//
//    var imageToEdit: UIImage?
//    var onSave: ((UIImage) -> Void)?
//    var onCancel: (() -> Void)?
//
//    private var imageView: UIImageView!
//    private var interaction: ImageAnalysisInteraction!
//    private let analyzer = ImageAnalyzer()
//    
//    // 加载指示器 (全屏遮罩，防止用户重复点击)
//    private let loadingOverlay: UIView = {
//        let view = UIView()
//        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
//        view.isHidden = true
//        view.isUserInteractionEnabled = true // 确保遮罩层能拦截点击
//        
//        let spinner = UIActivityIndicatorView(style: .large)
//        spinner.color = .white
//        spinner.startAnimating()
//        spinner.translatesAutoresizingMaskIntoConstraints = false
//        
//        view.addSubview(spinner)
//        NSLayoutConstraint.activate([
//            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
//        ])
//        return view
//    }()
//    
//    // 底部提示标签
//    private let hintLabel: UILabel = {
//        let label = UILabel()
//        label.text = "点击主体即可自动抠图保存"
//        label.textColor = .white.withAlphaComponent(0.9)
//        label.font = .systemFont(ofSize: 15, weight: .semibold)
//        label.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
//        label.layer.cornerRadius = 20
//        label.layer.masksToBounds = true
//        label.textAlignment = .center
//        return label
//    }()
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.backgroundColor = .black
//
//        setupImageView()
//        setupNavigationBar()
//        setupGestures()
//        
//        // 布局 Loading 遮罩
//        loadingOverlay.frame = view.bounds
//        loadingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        view.addSubview(loadingOverlay)
//        
//        // 布局提示标签
//        view.addSubview(hintLabel)
//        hintLabel.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            hintLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
//            hintLabel.widthAnchor.constraint(equalToConstant: 240),
//            hintLabel.heightAnchor.constraint(equalToConstant: 44)
//        ])
//        
//        // 开始分析
//        Task {
//            await initAnalysis()
//        }
//    }
//
//    private func setupImageView() {
//        imageView = UIImageView(frame: view.bounds)
//        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        imageView.contentMode = .scaleAspectFit
//        imageView.isUserInteractionEnabled = true
//        
//        if let img = imageToEdit {
//            imageView.image = img
//        }
//        view.addSubview(imageView)
//    }
//
//    private func setupNavigationBar() {
//        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
//        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .prominent, target: self, action: #selector(saveTapped))
//    }
//    
//    private func setupGestures() {
//        // ✨ 添加点击手势：用户点一下，就触发“抠图+保存”
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleImageTap))
//        imageView.addGestureRecognizer(tapGesture)
//    }
//
//    @objc private func cancelTapped() {
//        onCancel?()
//    }
//    
//    @objc private func saveTapped() {
//        if let currentImage = imageView.image {
//            onSave?(currentImage)
//        }
//    }
//
//    // MARK: - ✨ 核心逻辑：点击 -> 抠图 -> 自动保存
//    @objc private func handleImageTap() {
//        guard let currentImage = imageView.image else { return }
//        
//        // 1. 显示 Loading
//        loadingOverlay.isHidden = false
//        hintLabel.isHidden = true
//        
//        Task {
//            // 2. 执行抠图
//            if let croppedImage = await performSubjectLifting(on: currentImage) {
//                // 3. 抠图成功
//                await MainActor.run {
//                    // 直接调用保存并退出
//                    onSave?(croppedImage)
//                }
//            } else {
//                // 4. 抠图失败
//                await MainActor.run {
//                    loadingOverlay.isHidden = true
//                    hintLabel.isHidden = false
//                    hintLabel.text = "未识别到主体，请重试"
//                    hintLabel.backgroundColor = UIColor.red.withAlphaComponent(0.6)
//                    
//                    // 震动反馈
//                    let generator = UINotificationFeedbackGenerator()
//                    generator.notificationOccurred(.error)
//                    
//                    // 1.5秒后恢复提示文字
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//                        self.hintLabel.text = "点击主体即可自动抠图保存"
//                        self.hintLabel.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
//                    }
//                }
//            }
//        }
//    }
//
//    // MARK: - Vision 抠图算法
//    private func performSubjectLifting(on image: UIImage) async -> UIImage? {
//        guard #available(iOS 17.0, *), let cgImage = image.cgImage else { return nil }
//
//        return await Task.detached(priority: .userInitiated) { () -> UIImage? in
//            let request = VNGenerateForegroundInstanceMaskRequest()
//            let handler = VNImageRequestHandler(cgImage: cgImage)
//            
//            do {
//                try handler.perform([request])
//                guard let result = request.results?.first else { return nil }
//                
//                let pixelBuffer = try result.generateMaskedImage(
//                    ofInstances: result.allInstances,
//                    from: handler,
//                    croppedToInstancesExtent: true
//                )
//                
//                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
//                let context = CIContext()
//                if let newCgImage = context.createCGImage(ciImage, from: ciImage.extent) {
//                    return UIImage(cgImage: newCgImage)
//                }
//            } catch {
//                print("抠图失败: \(error)")
//                return nil
//            }
//            return nil
//        }.value
//    }
//
//    // MARK: - VisionKit 交互 (只用于发光展示)
//    func initAnalysis() async {
//        guard let image = imageView.image else { return }
//        
//        if interaction != nil {
//            imageView.removeInteraction(interaction)
//        }
//        
//        interaction = ImageAnalysisInteraction()
//        imageView.addInteraction(interaction)
//
//        let configuration = ImageAnalyzer.Configuration([.visualLookUp])
//
//        do {
//            let analysis = try await analyzer.analyze(image, configuration: configuration)
//            
//            await MainActor.run {
//                interaction.analysis = analysis
//                
//                if #available(iOS 17.0, *) {
//                    interaction.preferredInteractionTypes = [.imageSubject]
//                    
//                    // ⬇️⬇️⬇️ 修复点：使用 hasResults(for:) ⬇️⬇️⬇️
//                    if !analysis.hasResults(for: .visualLookUp) {
//                        hintLabel.text = "未检测到可抠图主体"
//                    }
//                    // ⬆️⬆️⬆️ 修复结束 ⬆️⬆️⬆️
//                } else {
//                    interaction.preferredInteractionTypes = .automatic
//                }
//            }
//        } catch {
//            print("分析失败: \(error)")
//        }
//    }
//}
//
// MARK: - SwiftUI Wrapper
struct AnalysisEditorWrapper: UIViewControllerRepresentable {
    var image: UIImage
    var onSave: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let analysisVC = AnalysisViewController()
        analysisVC.imageToEdit = image
        analysisVC.onSave = onSave
        analysisVC.onCancel = onCancel
        
        let nav = UINavigationController(rootViewController: analysisVC)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
