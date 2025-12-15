import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../utils/constants.dart';

class ModelDownloadService {
  /// 모델 다운로드 (진행률 콜백 포함)
  Future<String?> downloadModel({
    required String url,
    required String fileName,
    Function(int received, int total)? onProgress,
  }) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download model: ${response.statusCode}');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory(path.join(appDir.path, AppConstants.modelCacheDir));
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      final filePath = path.join(modelDir.path, fileName);
      final file = File(filePath);
      
      // 진행률 업데이트
      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      
      final bytes = response.bodyBytes;
      await file.writeAsBytes(bytes);
      receivedBytes = bytes.length;
      onProgress?.call(receivedBytes, totalBytes);

      return filePath;
    } catch (e) {
      print('Error downloading model: $e');
      rethrow;
    }
  }

  /// 모델 파일 존재 확인
  Future<bool> modelExists(String modelPath) async {
    return await File(modelPath).exists();
  }

  /// 모델 디렉토리 경로 가져오기
  Future<String> getModelDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(path.join(appDir.path, AppConstants.modelCacheDir));
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir.path;
  }

  /// 다운로드된 모델 목록 가져오기
  Future<List<String>> getDownloadedModels() async {
    try {
      final dir = await getModelDirectory();
      final directory = Directory(dir);
      if (!await directory.exists()) {
        return [];
      }
      
      return directory.listSync()
          .where((entity) => entity is File)
          .map((entity) => entity.path)
          .toList();
    } catch (e) {
      print('Error getting downloaded models: $e');
      return [];
    }
  }

  /// 모델 삭제
  Future<bool> deleteModel(String modelPath) async {
    try {
      final file = File(modelPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting model: $e');
      return false;
    }
  }
}

