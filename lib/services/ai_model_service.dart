import 'package:flutter/services.dart';
import '../models/generation_config.dart';
import '../utils/constants.dart';

class AIModelService {
  static const MethodChannel _channel = MethodChannel(AppConstants.platformChannelName);

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
      throw ArgumentError('inputImagePath and maskImagePath are required for inpainting');
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
}

