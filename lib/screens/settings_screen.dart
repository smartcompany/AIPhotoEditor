import 'dart:io';
import 'package:flutter/material.dart';
import '../services/ai_model_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AIModelService _aiService = AIModelService();

  bool _isModelLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loaded = await _aiService.isModelLoaded();
    setState(() {
      _isModelLoaded = loaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  const SizedBox(height: 8),
                  Text(
                    '모델은 필요할 때 자동으로 다운로드됩니다',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 모델 정보
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI 모델 정보',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• MODNet: 배경 제거용 모델\n'
                    '• Real-ESRGAN: 해상도 향상 및 노이즈 제거용 모델',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '모델은 AI 기능을 사용할 때 자동으로 다운로드됩니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 앱 정보
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '앱 정보',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '플랫폼: ${Platform.isIOS ? "iOS (CoreML)" : "Android (TFLite)"}',
                  ),
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
