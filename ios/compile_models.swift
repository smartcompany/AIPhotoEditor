#!/usr/bin/env swift

import Foundation
import CoreML

// 모델 컴파일 스크립트
// 사용법: swift compile_models.swift <model_name.mlpackage>

func compileModel(inputPath: String, outputPath: String) {
    let inputURL = URL(fileURLWithPath: inputPath)
    let outputURL = URL(fileURLWithPath: outputPath)
    
    print("📦 모델 컴파일 중: \(inputPath)")
    
    do {
        // 모델 컴파일
        let compiledURL = try MLModel.compileModel(at: inputURL)
        
        // 출력 디렉토리 생성
        let outputDir = outputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
        
        // 기존 파일 삭제 (있는 경우)
        try? FileManager.default.removeItem(at: outputURL)
        
        // 컴파일된 모델 이동
        try FileManager.default.moveItem(at: compiledURL, to: outputURL)
        
        print("✅ 컴파일 완료: \(outputPath)")
    } catch {
        print("❌ 컴파일 실패: \(error.localizedDescription)")
        exit(1)
    }
}

// 메인 실행
let arguments = CommandLine.arguments

if arguments.count < 2 {
    print("사용법: swift compile_models.swift <model_name.mlpackage> [output_path]")
    exit(1)
}

let inputPath = arguments[1]
let outputPath = arguments.count > 2 ? arguments[2] : inputPath.replacingOccurrences(of: ".mlpackage", with: ".mlmodelc")

compileModel(inputPath: inputPath, outputPath: outputPath)

