import 'dart:io';
import 'package:flutter/material.dart';
import '../services/ai_model_service.dart';
import '../services/model_download_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AIModelService _aiService = AIModelService();
  final ModelDownloadService _downloadService = ModelDownloadService();
  
  bool _isModelLoaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  List<String> _downloadedModels = [];
  String? _currentModelPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loaded = await _aiService.isModelLoaded();
    final models = await _downloadService.getDownloadedModels();
    setState(() {
      _isModelLoaded = loaded;
      _downloadedModels = models;
      if (models.isNotEmpty) {
        _currentModelPath = models.first;
      }
    });
  }

  Future<void> _downloadModel() async {
    // 실제 구현에서는 Hugging Face API를 통해 모델을 다운로드해야 합니다
    // 여기서는 예시로 간단한 다운로드 로직을 보여줍니다
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      // TODO: 실제 모델 다운로드 URL로 변경
      final modelUrl = AppConstants.coreMLModelUrl;
      final fileName = Platform.isIOS 
          ? 'stable_diffusion_v1_5.mlmodelc'
          : 'stable_diffusion_v1_5.tflite';

      final modelPath = await _downloadService.downloadModel(
        url: modelUrl,
        fileName: fileName,
        onProgress: (received, total) {
          setState(() {
            _downloadProgress = received / total;
          });
        },
      );

      if (modelPath != null) {
        // 모델 로드 시도
        final success = await _aiService.loadModel(modelPath);
        if (success) {
          setState(() {
            _isModelLoaded = true;
            _currentModelPath = modelPath;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('모델이 다운로드되고 로드되었습니다'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('다운로드 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        _loadSettings();
      }
    }
  }

  Future<void> _loadModel(String modelPath) async {
    try {
      final success = await _aiService.loadModel(modelPath);
      if (success) {
        setState(() {
          _isModelLoaded = true;
          _currentModelPath = modelPath;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('모델이 로드되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('모델 로드 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('모델 로드 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unloadModel() async {
    await _aiService.unloadModel();
    setState(() {
      _isModelLoaded = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모델이 언로드되었습니다'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 모델 상태
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '모델 상태',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        _isModelLoaded ? Icons.check_circle : Icons.cancel,
                        color: _isModelLoaded ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isModelLoaded ? '로드됨' : '로드되지 않음',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _isModelLoaded ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (_currentModelPath != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '경로: ${_currentModelPath!.split('/').last}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 모델 다운로드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '모델 다운로드',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isDownloading) ...[
                    LinearProgressIndicator(value: _downloadProgress),
                    const SizedBox(height: 8),
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ] else
                    ElevatedButton.icon(
                      onPressed: _downloadModel,
                      icon: const Icon(Icons.download),
                      label: const Text('모델 다운로드'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 다운로드된 모델 목록
          if (_downloadedModels.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '다운로드된 모델',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._downloadedModels.map((modelPath) {
                      final fileName = modelPath.split('/').last;
                      final isCurrent = modelPath == _currentModelPath;
                      return ListTile(
                        title: Text(fileName),
                        subtitle: Text(
                          isCurrent && _isModelLoaded
                              ? '현재 로드됨'
                              : '로드되지 않음',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isCurrent || !_isModelLoaded)
                              IconButton(
                                icon: const Icon(Icons.upload),
                                onPressed: () => _loadModel(modelPath),
                                tooltip: '로드',
                              ),
                            if (isCurrent && _isModelLoaded)
                              IconButton(
                                icon: const Icon(Icons.unarchive),
                                onPressed: _unloadModel,
                                tooltip: '언로드',
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 앱 정보
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '앱 정보',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('플랫폼: ${Platform.isIOS ? "iOS (CoreML)" : "Android (TFLite)"}'),
                  const SizedBox(height: 8),
                  Text('버전: 1.0.0'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

