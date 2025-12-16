import Foundation
import CoreML
import UIKit
import Accelerate
import Compression
import SSZipArchive

class AIModelHandler: NSObject, FlutterStreamHandler {
    private var model: MLModel?
    private var isModelLoaded: Bool = false
    private var modnetModel: MLModel? // MODNet CoreML 모델
    private var realesrganX2Model: MLModel? // Real-ESRGAN x2 CoreML 모델
    private var methodChannel: FlutterMethodChannel?
    private var eventSink: FlutterEventSink?
    
    // 모델 다운로드 URL (미리 컴파일된 .mlmodelc 파일)
    private let modnetURL = "https://github.com/smartcompany/models/releases/download/1.0.0/modnet.mlmodelc.zip"
    private let realesrganURL = "https://github.com/smartcompany/models/releases/download/1.0.0/realesrgan_x2plus.mlmodelc.zip"
    
    func setupChannels(methodChannel: FlutterMethodChannel, eventChannel: FlutterEventChannel) {
        self.methodChannel = methodChannel
        methodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handle(call: call, result: result)
        }
        eventChannel.setStreamHandler(self)
    }
    
    // FlutterStreamHandler 구현
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    private func sendProgress(modelName: String, progress: Double, status: String) {
        DispatchQueue.main.async {
            self.eventSink?([
                "modelName": modelName,
                "progress": progress,
                "status": status
            ])
        }
    }
    
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
            
        case "portraitMode":
            guard let args = call.arguments as? [String: Any],
                  let imagePath = args["imagePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Image path is required", details: nil))
                return
            }
            portraitMode(imagePath: imagePath, result: result)
            
        case "autoEnhance":
            guard let args = call.arguments as? [String: Any],
                  let imagePath = args["imagePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Image path is required", details: nil))
                return
            }
            autoEnhance(imagePath: imagePath, result: result)
            
        case "upscale":
            guard let args = call.arguments as? [String: Any],
                  let imagePath = args["imagePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Image path is required", details: nil))
                return
            }
            let scale = args["scale"] as? Int ?? 2
            upscale(imagePath: imagePath, scale: scale, result: result)
            
        case "reduceNoise":
            guard let args = call.arguments as? [String: Any],
                  let imagePath = args["imagePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Image path is required", details: nil))
                return
            }
            reduceNoise(imagePath: imagePath, result: result)
            
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
                    // 로컬 모델 URL 확인 (Documents 또는 Bundle)
                    if let modelURL = self.getLocalModelURL(modelName: "modnet") {
                        do {
                            let config = MLModelConfiguration()
                            config.computeUnits = .all
                            self.modnetModel = try MLModel(contentsOf: modelURL, configuration: config)
                            print("✅ MODNet 모델 로드 완료")
                            self.continueRemoveBackground(inputImage: inputImage, result: result)
                            return
                        } catch {
                            print("⚠️ MODNet 모델 로드 실패: \(error)")
                        }
                    }
                    
                    // 모델이 없으면 다운로드
                    self.ensureModelDownloaded(modelName: "modnet", url: self.modnetURL) { [weak self] success in
                        guard let self = self else { return }
                        if success {
                            if let modelURL = self.getLocalModelURL(modelName: "modnet") {
                                do {
                                    let config = MLModelConfiguration()
                                    config.computeUnits = .all
                                    self.modnetModel = try MLModel(contentsOf: modelURL, configuration: config)
                                    print("✅ MODNet 모델 로드 완료")
                                    self.continueRemoveBackground(inputImage: inputImage, result: result)
                                } catch {
                                    DispatchQueue.main.async {
                                        result(FlutterError(code: "MODEL_LOAD_ERROR", message: "Failed to load MODNet model: \(error.localizedDescription)", details: nil))
                                    }
                                }
                            } else {
                                DispatchQueue.main.async {
                                    result(FlutterError(code: "MODEL_LOAD_ERROR", message: "MODNet 모델 파일을 찾을 수 없습니다", details: nil))
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                result(FlutterError(code: "MODEL_DOWNLOAD_ERROR", message: "Failed to download MODNet model", details: nil))
                            }
                        }
                    }
                    return
                }
                
                self.continueRemoveBackground(inputImage: inputImage, result: result)
            }
        }
    }
    
    private func continueRemoveBackground(inputImage: UIImage, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
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
                
                // 3. CoreML 모델 직접 실행 (MLFeatureProvider 사용)
                let inputFeature = try MLFeatureValue(multiArray: inputArray)
                let inputProvider = try MLDictionaryFeatureProvider(dictionary: ["input": inputFeature])
                let prediction = try modnetModel.prediction(from: inputProvider)
                
                // 출력 추출 (모델의 출력 이름 확인 필요, 일반적으로 "output")
                guard let outputFeature = prediction.featureValue(for: "output"),
                      let maskArray = outputFeature.multiArrayValue else {
                    throw NSError(domain: "ModelError", code: -1, userInfo: [NSLocalizedDescriptionKey: "모델 출력을 찾을 수 없습니다"])
                }
                
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
    
    // MARK: - Portrait Mode (GFPGAN/CodeFormer)
    private func portraitMode(imagePath: String, result: @escaping FlutterResult) {
        guard let image = UIImage(contentsOfFile: imagePath) else {
            result(FlutterError(code: "INVALID_IMAGE", message: "Could not load image", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // TODO: GFPGAN CoreML 모델 로드 및 실행
            // 현재는 간단한 필터로 얼굴 보정 효과 적용
            guard let correctedImage = self.fixedOrientation(image) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "IMAGE_PROCESSING_ERROR", message: "Failed to correct image orientation", details: nil))
                }
                return
            }
            let processedImage = self.applyPortraitFilter(correctedImage)
            
            guard let outputPath = self.saveImage(processedImage, prefix: "portrait") else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SAVE_ERROR", message: "Failed to save processed image", details: nil))
                }
                return
            }
            
            DispatchQueue.main.async {
                result(outputPath)
            }
        }
    }
    
    // Portrait Mode 필터 적용 (임시 구현)
    private func applyPortraitFilter(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let context = CIContext()
        
        // 부드러운 블러 + 선명도 조정으로 피부 보정 효과
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return image }
        blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter.setValue(3.0, forKey: kCIInputRadiusKey)
        guard let blurredImage = blurFilter.outputImage else { return image }
        
        guard let sharpenFilter = CIFilter(name: "CIUnsharpMask") else { return image }
        sharpenFilter.setValue(ciImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(2.0, forKey: kCIInputRadiusKey)
        sharpenFilter.setValue(2.0, forKey: kCIInputIntensityKey)
        guard let sharpenedImage = sharpenFilter.outputImage else { return image }
        
        // 블러와 선명도를 블렌딩
        guard let blendFilter = CIFilter(name: "CISourceOverCompositing") else { return image }
        blendFilter.setValue(blurredImage, forKey: kCIInputImageKey)
        blendFilter.setValue(sharpenedImage, forKey: kCIInputBackgroundImageKey)
        guard let blendedImage = blendFilter.outputImage else { return image }
        
        guard let cgImage = context.createCGImage(blendedImage, from: ciImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Auto Enhance (Real-ESRGAN)
    private func autoEnhance(imagePath: String, result: @escaping FlutterResult) {
        guard let image = UIImage(contentsOfFile: imagePath) else {
            result(FlutterError(code: "INVALID_IMAGE", message: "Could not load image", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let correctedImage = self.fixedOrientation(image) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "IMAGE_PROCESSING_ERROR", message: "Failed to correct image orientation", details: nil))
                }
                return
            }
            
            // Real-ESRGAN x2 모델 사용 (향상 후 원본 크기로 리사이즈)
            if let processedImage = self.runRealESRGAN(correctedImage, scale: 2) {
                // 원본 크기로 리사이즈 (향상만 하고 크기는 유지)
                let originalSize = correctedImage.size
                guard let resizedImage = self.resizeImage(processedImage, to: originalSize) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "IMAGE_PROCESSING_ERROR", message: "Failed to resize enhanced image", details: nil))
                    }
                    return
                }
                
                guard let outputPath = self.saveImage(resizedImage, prefix: "enhanced") else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "SAVE_ERROR", message: "Failed to save processed image", details: nil))
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    result(outputPath)
                }
            } else {
                // 모델이 없으면 필터 폴백
                let processedImage = self.applyAutoEnhanceFilter(correctedImage)
                guard let outputPath = self.saveImage(processedImage, prefix: "enhanced") else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "SAVE_ERROR", message: "Failed to save processed image", details: nil))
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    result(outputPath)
                }
            }
        }
    }
    
    // Auto Enhance 필터 적용 (임시 구현)
    private func applyAutoEnhanceFilter(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let context = CIContext()
        
        // 밝기/대비/채도 조정
        guard let colorControls = CIFilter(name: "CIColorControls") else { return image }
        colorControls.setValue(ciImage, forKey: kCIInputImageKey)
        colorControls.setValue(1.05, forKey: kCIInputBrightnessKey) // 밝기 증가
        colorControls.setValue(1.08, forKey: kCIInputContrastKey) // 대비 증가
        colorControls.setValue(1.05, forKey: kCIInputSaturationKey) // 채도 증가
        guard let adjustedImage = colorControls.outputImage else { return image }
        
        // 선명도 향상
        guard let sharpenFilter = CIFilter(name: "CIUnsharpMask") else { return image }
        sharpenFilter.setValue(adjustedImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(1.5, forKey: kCIInputRadiusKey)
        sharpenFilter.setValue(1.5, forKey: kCIInputIntensityKey)
        guard let sharpenedImage = sharpenFilter.outputImage else { return image }
        
        guard let cgImage = context.createCGImage(sharpenedImage, from: ciImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Upscale (Real-ESRGAN)
    private func upscale(imagePath: String, scale: Int, result: @escaping FlutterResult) {
        guard let image = UIImage(contentsOfFile: imagePath) else {
            result(FlutterError(code: "INVALID_IMAGE", message: "Could not load image", details: nil))
            return
        }
        
        guard scale >= 2 && scale <= 4 else {
            result(FlutterError(code: "INVALID_SCALE", message: "Scale must be between 2 and 4", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let correctedImage = self.fixedOrientation(image) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "IMAGE_PROCESSING_ERROR", message: "Failed to correct image orientation", details: nil))
                }
                return
            }
            
            // Real-ESRGAN x2 모델 로드 및 다운로드 확인
            self.loadRealESRGANModel { [weak self] success in
                guard let self = self, success else {
                    // 모델이 없으면 필터 폴백
                    let processedImage = self?.applyUpscaleFilter(correctedImage, scale: scale) ?? correctedImage
                    guard let outputPath = self?.saveImage(processedImage, prefix: "upscale_x\(scale)") else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "SAVE_ERROR", message: "Failed to save processed image", details: nil))
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        result(outputPath)
                    }
                    return
                }
                
                // Real-ESRGAN x2 모델 사용
                // scale=2: x2 모델 1번 적용
                // scale=4: x2 모델 2번 적용 (x2 * x2 = x4)
                if scale == 2 {
                    if let processedImage = self.runRealESRGAN(correctedImage, scale: 2) {
                        guard let outputPath = self.saveImage(processedImage, prefix: "upscale_x2") else {
                            DispatchQueue.main.async {
                                result(FlutterError(code: "SAVE_ERROR", message: "Failed to save processed image", details: nil))
                            }
                            return
                        }
                        
                        DispatchQueue.main.async {
                            result(outputPath)
                        }
                        return
                    }
                } else if scale == 4 {
                    // x2 모델을 2번 적용하여 x4 효과
                    if let firstUpscale = self.runRealESRGAN(correctedImage, scale: 2),
                       let secondUpscale = self.runRealESRGAN(firstUpscale, scale: 2) {
                        guard let outputPath = self.saveImage(secondUpscale, prefix: "upscale_x4") else {
                            DispatchQueue.main.async {
                                result(FlutterError(code: "SAVE_ERROR", message: "Failed to save processed image", details: nil))
                            }
                            return
                        }
                        
                        DispatchQueue.main.async {
                            result(outputPath)
                        }
                        return
                    }
                }
                
                // 모델 실행 실패 시 필터 폴백
                let processedImage = self.applyUpscaleFilter(correctedImage, scale: scale)
                guard let outputPath = self.saveImage(processedImage, prefix: "upscale_x\(scale)") else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "SAVE_ERROR", message: "Failed to save processed image", details: nil))
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    result(outputPath)
                }
            }
        }
    }
    
    // Upscale 필터 적용 (임시 구현)
    private func applyUpscaleFilter(_ image: UIImage, scale: Int) -> UIImage {
        let newSize = CGSize(
            width: image.size.width * CGFloat(scale),
            height: image.size.height * CGFloat(scale)
        )
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        guard let upscaledImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return image
        }
        
        return upscaledImage
    }
    
    // MARK: - Reduce Noise (Real-ESRGAN)
    private func reduceNoise(imagePath: String, result: @escaping FlutterResult) {
        guard let image = UIImage(contentsOfFile: imagePath) else {
            result(FlutterError(code: "INVALID_IMAGE", message: "Could not load image", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let correctedImage = self.fixedOrientation(image) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "IMAGE_PROCESSING_ERROR", message: "Failed to correct image orientation", details: nil))
                }
                return
            }
            
            // Real-ESRGAN x2 모델 로드 및 다운로드 확인
            self.loadRealESRGANModel { [weak self] success in
                guard let self = self else { return }
                
                if success, let processedImage = self.runRealESRGAN(correctedImage, scale: 2) {
                    // 원본 크기로 리사이즈 (노이즈 제거만 하고 크기는 유지)
                    let originalSize = correctedImage.size
                    guard let resizedImage = self.resizeImage(processedImage, to: originalSize) else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "IMAGE_PROCESSING_ERROR", message: "Failed to resize denoised image", details: nil))
                        }
                        return
                    }
                    
                    guard let outputPath = self.saveImage(resizedImage, prefix: "denoise") else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "SAVE_ERROR", message: "Failed to save processed image", details: nil))
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        result(outputPath)
                    }
                } else {
                    // 모델이 없으면 필터 폴백
                    let processedImage = self.applyDenoiseFilter(correctedImage)
                    guard let outputPath = self.saveImage(processedImage, prefix: "denoise") else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "SAVE_ERROR", message: "Failed to save processed image", details: nil))
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        result(outputPath)
                    }
                }
            }
        }
    }
    
    // MARK: - Real-ESRGAN CoreML 모델 실행
    private func loadRealESRGANModel(completion: @escaping (Bool) -> Void) {
        if realesrganX2Model != nil {
            completion(true)
            return
        }
        
        // 로컬 파일 확인
        if let modelURL = getLocalModelURL(modelName: "realesrgan_x2plus") {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all
                realesrganX2Model = try MLModel(contentsOf: modelURL, configuration: config)
                print("✅ Real-ESRGAN x2 모델 로드 완료")
                completion(true)
                return
            } catch {
                print("❌ Real-ESRGAN x2 모델 로드 실패: \(error)")
            }
        }
        
        // 모델이 없으면 다운로드
        ensureModelDownloaded(modelName: "realesrgan_x2plus", url: realesrganURL) { [weak self] success in
            guard let self = self, success else {
                completion(false)
                return
            }
            
            if let modelURL = self.getLocalModelURL(modelName: "realesrgan_x2plus") {
                do {
                    let config = MLModelConfiguration()
                    config.computeUnits = .all
                    self.realesrganX2Model = try MLModel(contentsOf: modelURL, configuration: config)
                    print("✅ Real-ESRGAN x2 모델 로드 완료")
                    completion(true)
                } catch {
                    print("❌ Real-ESRGAN x2 모델 로드 실패: \(error)")
                    completion(false)
                }
            } else {
                completion(false)
            }
        }
    }
    
    private func loadRealESRGANModelSync() -> MLModel? {
        if let modelURL = getLocalModelURL(modelName: "realesrgan_x2plus") {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all
                return try MLModel(contentsOf: modelURL, configuration: config)
            } catch {
                print("❌ Real-ESRGAN x2 모델 로드 실패: \(error)")
            }
        }
        return nil
    }
    
    private func runRealESRGAN(_ image: UIImage, scale: Int) -> UIImage? {
        // 항상 x2 모델 사용 (scale 파라미터는 호환성을 위해 유지)
        guard let model = loadRealESRGANModelSync() else {
            return nil
        }
        
        // 이미지를 모델 입력 크기로 리사이즈 (일반적으로 512x512 또는 원본 크기)
        // Real-ESRGAN은 다양한 입력 크기를 지원하지만, 메모리 효율을 위해 타일링 처리 필요할 수 있음
        let inputSize = image.size
        guard let pixelBuffer = imageToPixelBuffer(image, size: inputSize) else {
            print("❌ 이미지를 PixelBuffer로 변환 실패")
            return nil
        }
        
        do {
            // 모델 입력 생성 (실제 모델의 입력 형식에 맞춰야 함)
            // Real-ESRGAN CoreML 모델의 입력 형식에 따라 조정 필요
            let input = try MLDictionaryFeatureProvider(dictionary: ["input": MLFeatureValue(pixelBuffer: pixelBuffer)])
            
            // 모델 실행
            let prediction = try model.prediction(from: input)
            
            // 출력 추출 (실제 모델의 출력 형식에 맞춰야 함)
            guard let outputFeature = prediction.featureValue(for: "output"),
                  let outputPixelBuffer = outputFeature.imageBufferValue else {
                print("❌ 모델 출력 추출 실패")
                return nil
            }
            
            // PixelBuffer를 UIImage로 변환
            return pixelBufferToImage(outputPixelBuffer)
            
        } catch {
            print("❌ Real-ESRGAN 모델 실행 실패: \(error)")
            return nil
        }
    }
    
    // Denoise 필터 적용 (임시 구현)
    private func applyDenoiseFilter(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let context = CIContext()
        
        // 약한 블러로 노이즈 제거
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return image }
        blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter.setValue(1.2, forKey: kCIInputRadiusKey)
        guard let blurredImage = blurFilter.outputImage else { return image }
        
        // 선명도 회복
        guard let sharpenFilter = CIFilter(name: "CIUnsharpMask") else { return image }
        sharpenFilter.setValue(blurredImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(1.0, forKey: kCIInputRadiusKey)
        sharpenFilter.setValue(1.2, forKey: kCIInputIntensityKey)
        guard let sharpenedImage = sharpenFilter.outputImage else { return image }
        
        guard let cgImage = context.createCGImage(sharpenedImage, from: ciImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // 이미지 저장 헬퍼 함수
    private func saveImage(_ image: UIImage, prefix: String) -> String? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "\(prefix)_\(timestamp).png"
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        guard let imageData = image.pngData() else {
            return nil
        }
        
        do {
            try imageData.write(to: fileURL)
            return fileURL.path
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    // MARK: - 모델 다운로드 및 관리
    private func getLocalModelURL(modelName: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // 컴파일된 .mlmodelc 파일 확인 (다운로드된 모델)
        let compiledModelPath = documentsPath.appendingPathComponent("models/\(modelName).mlmodelc")
        if FileManager.default.fileExists(atPath: compiledModelPath.path) {
            return compiledModelPath
        }
        
        // Bundle에서 확인 (이미 컴파일되어 있음)
        if let bundleURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
            return bundleURL
        }
        
        return nil
    }
    
    private func ensureModelDownloaded(modelName: String, url: String, completion: @escaping (Bool) -> Void) {
        // 이미 로컬에 있으면 바로 반환
        if getLocalModelURL(modelName: modelName) != nil {
            sendProgress(modelName: modelName, progress: 1.0, status: "모델 준비 완료")
            completion(true)
            return
        }
        
        sendProgress(modelName: modelName, progress: 0.0, status: "다운로드 시작...")
        
        guard let downloadURL = URL(string: url) else {
            sendProgress(modelName: modelName, progress: 0.0, status: "다운로드 URL 오류")
            completion(false)
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = documentsPath.appendingPathComponent("models")
        let zipPath = modelsDir.appendingPathComponent("\(modelName).zip")
        let extractPath = modelsDir.appendingPathComponent(modelName)
        
        // 디렉토리 생성
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true, attributes: nil)
        
        // 다운로드
        let task = URLSession.shared.downloadTask(with: downloadURL) { [weak self] tempURL, response, error in
            guard let self = self else {
                completion(false)
                return
            }
            
            if let error = error {
                print("❌ 다운로드 실패: \(error.localizedDescription)")
                self.sendProgress(modelName: modelName, progress: 0.0, status: "다운로드 실패: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let tempURL = tempURL else {
                self.sendProgress(modelName: modelName, progress: 0.0, status: "다운로드 실패: 임시 파일 없음")
                completion(false)
                return
            }
            
            // zip 파일 저장
            do {
                try FileManager.default.moveItem(at: tempURL, to: zipPath)
                self.sendProgress(modelName: modelName, progress: 0.5, status: "압축 해제 중...")
                
                // zip 해제
                try self.unzipFile(at: zipPath, to: extractPath)
                
                // zip 파일 삭제
                try? FileManager.default.removeItem(at: zipPath)
                
                // .mlmodelc 파일 확인
                let compiledModelPath = extractPath.appendingPathComponent("\(modelName).mlmodelc")
                
                guard FileManager.default.fileExists(atPath: compiledModelPath.path) else {
                    self.sendProgress(modelName: modelName, progress: 0.0, status: "압축 해제 실패: .mlmodelc 파일 없음")
                    completion(false)
                    return
                }
                
                // 컴파일된 .mlmodelc 파일을 models 디렉토리로 이동
                let finalPath = modelsDir.appendingPathComponent("\(modelName).mlmodelc")
                try? FileManager.default.removeItem(at: finalPath)
                try FileManager.default.moveItem(at: compiledModelPath, to: finalPath)
                try? FileManager.default.removeItem(at: extractPath)
                
                self.sendProgress(modelName: modelName, progress: 1.0, status: "다운로드 완료")
                completion(true)
            } catch {
                print("❌ 파일 처리 실패: \(error.localizedDescription)")
                self.sendProgress(modelName: modelName, progress: 0.0, status: "파일 처리 실패: \(error.localizedDescription)")
                completion(false)
            }
        }
        
        // 진행도 모니터링
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            guard let self = self else { return }
            let percent = progress.fractionCompleted * 0.5 // 다운로드는 50%까지
            self.sendProgress(modelName: modelName, progress: percent, status: "다운로드 중... \(Int(percent * 100))%")
        }
        
        task.resume()
    }
    
    private func unzipFile(at zipPath: URL, to destinationPath: URL) throws {
        // SSZipArchive를 사용한 zip 해제
        // 디렉토리 생성
        try? FileManager.default.createDirectory(at: destinationPath, withIntermediateDirectories: true, attributes: nil)
        
        // SSZipArchive로 zip 해제
        var error: NSError?
        let success = SSZipArchive.unzipFile(
            atPath: zipPath.path,
            toDestination: destinationPath.path,
            preserveAttributes: true,
            overwrite: true,
            password: nil,
            error: &error,
            delegate: nil
        )
        
        if !success {
            let errorMessage = error?.localizedDescription ?? "압축 해제 실패"
            throw NSError(domain: "UnzipError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }
    
    private func copyModelToBundleIfNeeded(modelName: String, from sourceURL: URL) {
        // Bundle은 읽기 전용이므로 실제로는 복사할 수 없음
        // 대신 Documents 디렉토리의 모델을 직접 사용하도록 수정 필요
        // 일단 이 함수는 placeholder로 남겨둠
    }
}

