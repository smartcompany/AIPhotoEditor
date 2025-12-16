import 'package:flutter/services.dart';
import '../models/generation_config.dart';
import '../utils/constants.dart';

class AIModelService {
  static const MethodChannel _channel = MethodChannel(
    AppConstants.platformChannelName,
  );

  /// 모델 로드 상태 확인
  Future<bool> isModelLoaded() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        AppConstants.methodGetModelStatus,
      );
      return result ?? false;
    } catch (e) {
      print('Error checking model status: $e');
      return false;
    }
  }

  /// 모델 로드
  Future<bool> loadModel(String modelPath) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        AppConstants.methodLoadModel,
        {'modelPath': modelPath},
      );
      return result ?? false;
    } catch (e) {
      print('Error loading model: $e');
      rethrow;
    }
  }

  /// Image-to-Image 변환
  Future<String?> imageToImage(GenerationConfig config) async {
    if (config.inputImagePath == null) {
      throw ArgumentError('inputImagePath is required for image-to-image');
    }
    try {
      final result = await _channel.invokeMethod<String>(
        AppConstants.methodImageToImage,
        config.toMap(),
      );
      return result;
    } catch (e) {
      print('Error in image-to-image: $e');
      rethrow;
    }
  }

  /// Inpainting (선택 영역 보정)
  Future<String?> inpaint(GenerationConfig config) async {
    if (config.inputImagePath == null || config.maskImagePath == null) {
      throw ArgumentError(
        'inputImagePath and maskImagePath are required for inpainting',
      );
    }
    try {
      final result = await _channel.invokeMethod<String>(
        AppConstants.methodInpaint,
        config.toMap(),
      );
      return result;
    } catch (e) {
      print('Error in inpainting: $e');
      rethrow;
    }
  }

  /// 모델 언로드 (메모리 해제)
  Future<void> unloadModel() async {
    try {
      await _channel.invokeMethod(AppConstants.methodUnloadModel);
    } catch (e) {
      print('Error unloading model: $e');
    }
  }

  /// Remove Background: MODNet을 사용한 배경 제거
  Future<String?> removeBackground(String imagePath) async {
    if (imagePath.isEmpty) {
      throw ArgumentError('imagePath is required for background removal');
    }
    try {
      final result = await _channel.invokeMethod<String>(
        AppConstants.methodRemoveBackground,
        {'imagePath': imagePath},
      );
      return result;
    } catch (e) {
      print('Error in remove background: $e');
      rethrow;
    }
  }

  /// Portrait Mode: 네이티브 AI 모델을 사용한 얼굴 보정
  Future<String?> portraitMode(String imagePath) async {
    if (imagePath.isEmpty) {
      throw ArgumentError('imagePath is required for portrait mode');
    }
    try {
      final result = await _channel.invokeMethod<String>(
        AppConstants.methodPortraitMode,
        {'imagePath': imagePath},
      );
      return result;
    } catch (e) {
      print('Error in portrait mode: $e');
      rethrow;
    }
  }

  /// Auto Enhance: 네이티브 AI 모델을 사용한 이미지 자동 향상
  Future<String?> autoEnhance(String imagePath) async {
    if (imagePath.isEmpty) {
      throw ArgumentError('imagePath is required for auto enhance');
    }
    try {
      final result = await _channel.invokeMethod<String>(
        AppConstants.methodAutoEnhance,
        {'imagePath': imagePath},
      );
      return result;
    } catch (e) {
      print('Error in auto enhance: $e');
      rethrow;
    }
  }

  /// Upscale: 네이티브 AI 모델을 사용한 해상도 향상
  Future<String?> upscale(String imagePath, {int scale = 2}) async {
    if (imagePath.isEmpty) {
      throw ArgumentError('imagePath is required for upscale');
    }
    try {
      final result = await _channel.invokeMethod<String>(
        AppConstants.methodUpscale,
        {'imagePath': imagePath, 'scale': scale},
      );
      return result;
    } catch (e) {
      print('Error in upscale: $e');
      rethrow;
    }
  }

  /// Reduce Noise: 네이티브 AI 모델을 사용한 노이즈 제거
  Future<String?> reduceNoise(String imagePath) async {
    if (imagePath.isEmpty) {
      throw ArgumentError('imagePath is required for noise reduction');
    }
    try {
      final result = await _channel.invokeMethod<String>(
        AppConstants.methodReduceNoise,
        {'imagePath': imagePath},
      );
      return result;
    } catch (e) {
      print('Error in reduce noise: $e');
      rethrow;
    }
  }
}
