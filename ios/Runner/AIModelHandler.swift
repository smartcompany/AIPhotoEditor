import Foundation
import CoreML
import UIKit
import Accelerate

class AIModelHandler {
    private var model: MLModel?
    private var isModelLoaded: Bool = false
    
    func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getModelStatus":
            result(isModelLoaded)
            
        case "loadModel":
            guard let args = call.arguments as? [String: Any],
                  let modelPath = args["modelPath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Model path is required", details: nil))
                return
            }
            loadModel(path: modelPath, result: result)
            
        case "imageToImage":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                return
            }
            imageToImage(args: args, result: result)
            
        case "inpaint":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                return
            }
            inpaint(args: args, result: result)
            
        case "unloadModel":
            unloadModel(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func loadModel(path: String, result: @escaping FlutterResult) {
        do {
            let modelURL = URL(fileURLWithPath: path)
            let config = MLModelConfiguration()
            config.computeUnits = .all // Use Neural Engine, GPU, and CPU
            
            model = try MLModel(contentsOf: modelURL, configuration: config)
            isModelLoaded = true
            result(true)
        } catch {
            print("Error loading model: \(error)")
            result(FlutterError(code: "MODEL_LOAD_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func imageToImage(args: [String: Any], result: @escaping FlutterResult) {
        guard isModelLoaded, let model = model else {
            result(FlutterError(code: "MODEL_NOT_LOADED", message: "Model is not loaded", details: nil))
            return
        }
        
        guard let inputImagePath = args["inputImagePath"] as? String,
              let inputImage = UIImage(contentsOfFile: inputImagePath) else {
            result(FlutterError(code: "INVALID_IMAGE", message: "Invalid input image", details: nil))
            return
        }
        
        // TODO: Image-to-Image 구현
        DispatchQueue.global(qos: .userInitiated).async {
            // 임시로 원본 이미지 경로 반환
            DispatchQueue.main.async {
                result(inputImagePath)
            }
        }
    }
    
    private func inpaint(args: [String: Any], result: @escaping FlutterResult) {
        guard isModelLoaded, let model = model else {
            result(FlutterError(code: "MODEL_NOT_LOADED", message: "Model is not loaded", details: nil))
            return
        }
        
        guard let inputImagePath = args["inputImagePath"] as? String,
              let maskImagePath = args["maskImagePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Input image and mask are required", details: nil))
            return
        }
        
        // TODO: Inpainting 구현
        DispatchQueue.global(qos: .userInitiated).async {
            // 임시로 원본 이미지 경로 반환
            DispatchQueue.main.async {
                result(inputImagePath)
            }
        }
    }
    
    private func unloadModel(result: @escaping FlutterResult) {
        model = nil
        isModelLoaded = false
        result(true)
    }
    
    // 임시 더미 이미지 생성 (실제 구현에서는 제거)
    private func createDummyImage(width: Int, height: Int) -> String {
        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.systemPurple.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagePath = documentsPath.appendingPathComponent("generated_\(UUID().uuidString).png")
        
        if let imageData = image.pngData() {
            try? imageData.write(to: imagePath)
            return imagePath.path
        }
        
        return ""
    }
}

