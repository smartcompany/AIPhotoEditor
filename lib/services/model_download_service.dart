import 'package:flutter/services.dart';
import 'dart:async';

/// 모델 다운로드 진행도 정보
class ModelDownloadProgress {
  final String modelName;
  final double progress; // 0.0 ~ 1.0
  final String status;

  ModelDownloadProgress({
    required this.modelName,
    required this.progress,
    required this.status,
  });

  factory ModelDownloadProgress.fromMap(Map<dynamic, dynamic> map) {
    return ModelDownloadProgress(
      modelName: map['modelName'] as String? ?? '',
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? '',
    );
  }
}

/// 모델 다운로드 서비스
class ModelDownloadService {
  static const EventChannel _eventChannel = EventChannel(
    'com.aiphotoeditor/ai_model_progress',
  );

  StreamSubscription<dynamic>? _subscription;
  StreamController<ModelDownloadProgress>? _progressController;

  /// 진행도 스트림 구독 시작
  Stream<ModelDownloadProgress> getProgressStream() {
    _progressController ??= StreamController<ModelDownloadProgress>.broadcast();

    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final progress = ModelDownloadProgress.fromMap(event);
          _progressController?.add(progress);
        }
      },
      onError: (error) {
        _progressController?.addError(error);
      },
    );

    return _progressController!.stream;
  }

  /// 진행도 스트림 구독 취소
  void cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
    _progressController?.close();
    _progressController = null;
  }

  /// 모델 이름을 한국어로 변환
  static String getModelDisplayName(String modelName) {
    switch (modelName) {
      case 'modnet':
        return 'MODNet (배경 제거)';
      case 'realesrgan_x2plus':
        return 'Real-ESRGAN (해상도 향상)';
      default:
        return modelName;
    }
  }
}
