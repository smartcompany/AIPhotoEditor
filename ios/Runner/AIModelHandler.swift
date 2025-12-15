import Foundation
import CoreML
import UIKit
import Accelerate

class AIModelHandler {
    private var model: MLModel?
    private var isModelLoaded: Bool = false
    private var modnetModel: modnet? // MODNet CoreML 모델
    
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
            
        case "removeBackground":
            guard let args = call.arguments as? [String: Any],
                  let imagePath = args["imagePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Image path is required", details: nil))
                return
            }
            removeBackground(imagePath: imagePath, result: result)
            
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
    
    private func removeBackground(imagePath: String, result: @escaping FlutterResult) {
        guard let rawImage = UIImage(contentsOfFile: imagePath) else {
            result(FlutterError(code: "INVALID_IMAGE", message: "Could not load image", details: nil))
            return
        }
        
        // EXIF 방향 보정 (회전 문제 방지)
        guard let inputImage = fixedOrientation(rawImage) else {
            result(FlutterError(code: "IMAGE_PROCESSING_ERROR", message: "Failed to normalize image orientation", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 1. MODNet CoreML 모델 로드 (처음 한 번만)
                if self.modnetModel == nil {
                    let config = MLModelConfiguration()
                    config.computeUnits = .all
                    self.modnetModel = try modnet(configuration: config)
                }
                
                guard let modnetModel = self.modnetModel else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "MODEL_LOAD_ERROR", message: "MODNet model is nil after initialization", details: nil))
                    }
                    return
                }
                
                // 2. 입력 이미지를 모델 입력 크기로 리사이즈 (512x512 기준)
                let targetSize = CGSize(width: 512, height: 512)
                guard let resizedImage = self.resizeImage(inputImage, to: targetSize),
                      let inputArray = self.imageToInputArray(resizedImage, size: targetSize) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "IMAGE_PROCESSING_ERROR", message: "Failed to prepare input for MODNet (image → MLMultiArray)", details: nil))
                    }
                    return
                }
                
                // 3. CoreML 모델 직접 실행 (생성된 modnetInput 클래스를 사용)
                let modnetInput = modnetInput(input: inputArray)
                let prediction = try modnetModel.prediction(input: modnetInput)
                let maskArray = prediction.output
                
                // 4. MLMultiArray -> 마스크 UIImage 변환
                guard let rawMaskImage = self.multiArrayToMaskImage(maskArray) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "MODEL_PREDICTION_ERROR", message: "Failed to convert MODNet output to mask image", details: nil))
                    }
                    return
                }
                
                // 5. 마스크를 원본 크기로 리사이즈 후 적용
                guard let resizedMask = self.resizeImage(rawMaskImage, to: inputImage.size),
                      let resultImage = self.applyMask(inputImage, mask: resizedMask) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "IMAGE_PROCESSING_ERROR", message: "Failed to apply MODNet mask to image", details: nil))
                    }
                    return
                }
                
                // 6. 결과 이미지 저장
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let outputPath = documentsPath.appendingPathComponent("removed_bg_\(UUID().uuidString).png")
                
                guard let imageData = resultImage.pngData() else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "IMAGE_SAVE_ERROR", message: "Failed to convert result image to PNG", details: nil))
                    }
                    return
                }
                
                try imageData.write(to: outputPath)
                
                DispatchQueue.main.async {
                    result(outputPath.path)
                }
                
            } catch {
                print("❌ MODNet CoreML prediction failed: \(error)")
                let nsError = error as NSError
                print("  domain: \(nsError.domain)")
                print("  code: \(nsError.code)")
                print("  userInfo: \(nsError.userInfo)")
                
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "MODEL_PREDICTION_ERROR",
                            message: "Failed to run MODNet prediction: \(error)",
                            details: nsError.userInfo
                        )
                    )
                }
            }
        }
    }
    
    // UIImage -> MODNet 입력용 MLMultiArray (shape: [1, 3, H, W], 0~1 normalize)
    private func imageToInputArray(_ image: UIImage, size: CGSize) -> MLMultiArray? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = Int(size.width)
        let height = Int(size.height)
        let channels = 3
        
        // 1x3xHxW
        guard let array = try? MLMultiArray(
            shape: [1, NSNumber(value: channels), NSNumber(value: height), NSNumber(value: width)],
            dataType: .float32
        ) else {
            return nil
        }
        
        // RGBA 8비트 버퍼에 이미지 그리기
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        
        // RGBA → NCHW(Float32) [0,1] 정규화
        let ptr = UnsafeMutablePointer<Float32>(OpaquePointer(array.dataPointer))
        
        func index(n: Int, c: Int, h: Int, w: Int) -> Int {
            // n * (C*H*W) + c * (H*W) + h * W + w
            return n * (channels * height * width) + c * (height * width) + h * width + w
        }
        
        for h in 0..<height {
            for w in 0..<width {
                let pixelIndex = h * bytesPerRow + w * bytesPerPixel
                let r = Float32(rawData[pixelIndex]) / 255.0
                let g = Float32(rawData[pixelIndex + 1]) / 255.0
                let b = Float32(rawData[pixelIndex + 2]) / 255.0
                
                ptr[index(n: 0, c: 0, h: h, w: w)] = r
                ptr[index(n: 0, c: 1, h: h, w: w)] = g
                ptr[index(n: 0, c: 2, h: h, w: w)] = b
            }
        }
        
        return array
    }
    
    // UIImage 방향을 항상 .up 으로 보정 (EXIF 회전 제거)
    // 회전된 결과가 나오는 문제를 방지하기 위해 사용
    private func fixedOrientation(_ image: UIImage) -> UIImage? {
        if image.imageOrientation == .up {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: image.size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // MLMultiArray (0~1 값의 마스크) -> 그레이스케일 UIImage로 변환
    private func multiArrayToMaskImage(_ array: MLMultiArray) -> UIImage? {
        // shape 예: [1, 1, H, W] 또는 [1, H, W, 1]
        let shape = array.shape.map { $0.intValue }
        guard shape.count >= 2 else { return nil }
        
        let height: Int
        let width: Int
        if shape.count == 2 {
            height = shape[0]
            width = shape[1]
        } else {
            // 마지막 두 차원을 H, W로 가정
            height = shape[shape.count - 2]
            width = shape[shape.count - 1]
        }
        
        let count = width * height
        guard count > 0 else { return nil }
        
        // Float32 배열로 가정 (coremltools 기본)
        let ptr = UnsafeMutablePointer<Float32>(OpaquePointer(array.dataPointer))
        var pixels = [UInt8](repeating: 0, count: count)
        
        for i in 0..<count {
            let v = ptr[i]
            let clamped = max(0.0, min(1.0, Float(v)))
            pixels[i] = UInt8(clamped * 255.0)
        }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: 0
        ) else {
            return nil
        }
        
        guard let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    // 이미지 리사이즈 헬퍼 함수
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // UIImage를 CVPixelBuffer로 변환
    private func imageToPixelBuffer(_ image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        
        return buffer
    }
    
    // CVPixelBuffer를 UIImage로 변환
    private func pixelBufferToImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    // 마스크를 적용하여 배경 제거
    private func applyMask(_ image: UIImage, mask: UIImage) -> UIImage? {
        guard let imageCG = image.cgImage,
              let maskCG = mask.cgImage else {
            return nil
        }
        
        let width = imageCG.width
        let height = imageCG.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // 마스크를 그레이스케일로 변환
        guard let maskContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        
        maskContext.draw(maskCG, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let grayMask = maskContext.makeImage() else {
            return nil
        }
        
        // 결과 이미지 생성 (투명 배경)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        // 마스크를 사용하여 클리핑
        context.clip(to: CGRect(x: 0, y: 0, width: width, height: height), mask: grayMask)
        
        // 원본 이미지 그리기
        context.draw(imageCG, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let resultCG = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: resultCG)
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

