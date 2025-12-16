import 'package:flutter/material.dart';
import '../services/model_download_service.dart';

/// 모델 다운로드 진행도 다이얼로그
class ModelDownloadDialog extends StatefulWidget {
  final String modelName;
  final Stream<ModelDownloadProgress> progressStream;

  const ModelDownloadDialog({
    super.key,
    required this.modelName,
    required this.progressStream,
  });

  @override
  State<ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<ModelDownloadDialog> {
  ModelDownloadProgress? _currentProgress;
  bool _isComplete = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _listenToProgress();
  }

  void _listenToProgress() {
    widget.progressStream.listen(
      (progress) {
        if (mounted) {
          setState(() {
            _currentProgress = progress;
            if (progress.progress >= 1.0) {
              _isComplete = true;
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error.toString();
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = ModelDownloadService.getModelDisplayName(
      widget.modelName,
    );

    return WillPopScope(
      onWillPop: () async {
        // 완료되기 전에는 닫을 수 없음
        return _isComplete || _errorMessage != null;
      },
      child: AlertDialog(
        title: Row(
          children: [
            if (!_isComplete && _errorMessage == null)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_isComplete)
              const Icon(Icons.check_circle, color: Colors.green, size: 20)
            else
              const Icon(Icons.error, color: Colors.red, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage != null ? '다운로드 실패' : displayName,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
              ] else if (_currentProgress != null) ...[
                // 진행도 바
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _currentProgress!.progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isComplete ? Colors.green : Colors.blue,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                // 진행도 텍스트
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _currentProgress!.status,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                    Text(
                      '${(_currentProgress!.progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
        actions: [
          if (_isComplete || _errorMessage != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(_errorMessage != null ? '닫기' : '확인'),
            ),
        ],
      ),
    );
  }
}
