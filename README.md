# OnDevice AI Photo Editor

Stable Diffusion CoreML / TFLite 기반의 온디바이스 AI 사진 보정 및 스타일 변환 Flutter 앱

## 🎯 주요 기능

- **Image-to-Image**: 원본 이미지를 기반으로 스타일 변환
- **Inpainting**: 선택 영역만 보정
- **온디바이스 처리**: 인터넷 연결 없이 로컬에서 AI 이미지 변환
- **iOS (CoreML)**: Apple의 Neural Engine 활용
- **Android (TFLite)**: GPU Delegate를 통한 가속화

## 📋 요구사항

- Flutter SDK 3.10.0 이상
- iOS 13.0 이상 (CoreML 지원)
- Android API 21 이상 (TFLite 지원)

## 🚀 시작하기

### 1. 의존성 설치

```bash
flutter pub get
```

### 2. iOS 설정

1. Xcode에서 `ios/Runner.xcworkspace` 열기
2. `AIModelHandler.swift` 파일이 프로젝트에 추가되었는지 확인
   - 없으면 수동으로 `ios/Runner/AIModelHandler.swift`를 Xcode 프로젝트에 추가
3. Info.plist에 필요한 권한이 설정되어 있는지 확인

### 3. Android 설정

1. `android/app/build.gradle.kts`에 TensorFlow Lite 의존성이 추가되어 있는지 확인
2. AndroidManifest.xml에 필요한 권한이 설정되어 있는지 확인

### 4. 모델 다운로드

앱 실행 후 설정 화면에서 모델을 다운로드하세요.

**iOS (CoreML)**:
- Apple의 CoreML Stable Diffusion 모델 사용
- 참고: https://github.com/apple/ml-stable-diffusion
- Hugging Face: https://huggingface.co/apple/coreml-stable-diffusion-v1-5

**Android (TFLite)**:
- TensorFlow Lite 경량화 모델 사용
- GPU Delegate를 통한 가속화 지원

## 📱 사용 방법

1. **홈 화면**:
   - 생성 타입 선택 (Image-to-Image, Inpaint)
   - 이미지 선택
   - 프롬프트 입력
   - 해상도 선택 (512x512, 768x768, 1024x1024)
   - "AI 생성" 버튼 클릭

2. **결과 화면**:
   - 생성된 이미지 확인
   - 갤러리에 저장
   - 다른 앱으로 공유

3. **설정 화면**:
   - 모델 다운로드
   - 모델 로드/언로드
   - 다운로드된 모델 관리

## 🏗️ 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── models/
│   └── generation_config.dart # 생성 설정 모델
├── screens/
│   ├── home_screen.dart      # 홈 화면
│   ├── result_screen.dart    # 결과 화면
│   └── settings_screen.dart  # 설정 화면
├── services/
│   ├── ai_model_service.dart      # AI 모델 서비스 (Platform Channel)
│   ├── image_service.dart         # 이미지 관리 서비스
│   └── model_download_service.dart # 모델 다운로드 서비스
└── utils/
    └── constants.dart        # 상수 정의

ios/
└── Runner/
    ├── AppDelegate.swift     # Flutter 엔진 설정
    └── AIModelHandler.swift # CoreML 통신 핸들러

android/
└── app/src/main/kotlin/com/aiphotoeditor/ai_photo_editor/
    ├── MainActivity.kt       # Flutter 엔진 설정
    └── AIModelHandler.kt    # TFLite 통신 핸들러
```

## ⚠️ 중요 사항

### 현재 구현 상태

이 프로젝트는 기본 구조와 Platform Channel 통신을 구현했습니다. 실제 AI 모델 실행 부분은 다음 작업이 필요합니다:

1. **iOS (CoreML)**:
   - Apple의 `ml-stable-diffusion` Swift 패키지 통합
   - 또는 CoreML 모델 직접 구현
   - 참고: https://github.com/apple/ml-stable-diffusion

2. **Android (TFLite)**:
   - Stable Diffusion TFLite 모델 변환
   - 모델 입력/출력 형식에 맞는 전처리/후처리 구현
   - GPU Delegate 최적화

### 모델 다운로드

현재 모델 다운로드 기능은 기본 구조만 구현되어 있습니다. 실제 모델 파일을 다운로드하려면:

1. Hugging Face API 또는 직접 다운로드 URL 사용
2. 모델 파일 형식 확인 (CoreML: `.mlmodelc`, TFLite: `.tflite`)
3. 모델 버전 관리 및 캐싱 구현

## 🔧 개발 가이드

### Platform Channel 통신

Flutter와 네이티브 코드 간 통신은 `MethodChannel`을 사용합니다:

- **Channel 이름**: `com.aiphotoeditor/ai_model`
- **메서드**:
  - `getModelStatus`: 모델 로드 상태 확인
  - `loadModel`: 모델 로드
  - `imageToImage`: Image-to-Image 변환
  - `inpaint`: Inpainting
  - `unloadModel`: 모델 언로드

### 메모리 관리

- 모델 사용 후 `unloadModel` 호출로 메모리 해제
- 이미지 처리 후 임시 파일 정리
- 대용량 모델의 경우 메모리 사용량 모니터링

## 📝 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다.

## 🙏 참고 자료

- [Flutter Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [Apple ML Stable Diffusion](https://github.com/apple/ml-stable-diffusion)
- [TensorFlow Lite](https://www.tensorflow.org/lite)
- [CoreML Documentation](https://developer.apple.com/documentation/coreml)
