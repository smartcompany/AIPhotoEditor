import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';
import 'ai_model_service.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();
  final AIModelService _aiService = AIModelService();

  /// 갤러리에서 이미지 선택
  Future<String?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (image == null) return null;

      // 임시 디렉토리에 복사
      final tempDir = await getTemporaryDirectory();
      final imageDir = Directory(
        path.join(tempDir.path, AppConstants.imageCacheDir),
      );
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      final fileName = path.basename(image.path);
      final savedPath = path.join(imageDir.path, fileName);
      await File(image.path).copy(savedPath);

      return savedPath;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// 이미지 파일 존재 확인
  Future<bool> imageExists(String imagePath) async {
    return await File(imagePath).exists();
  }

  /// 이미지 삭제
  Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  /// 생성된 이미지를 갤러리에 저장
  Future<bool> saveToGallery(String imagePath) async {
    try {
      // 권한 확인
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          return false;
        }
      }

      final result = await ImageGallerySaver.saveFile(imagePath);
      return result['isSuccess'] == true;
    } catch (e) {
      print('Error saving to gallery: $e');
      return false;
    }
  }

  /// 생성된 이미지 저장 디렉토리 가져오기
  Future<String> getGeneratedImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final generatedDir = Directory(
      path.join(appDir.path, AppConstants.generatedImagesDir),
    );
    if (!await generatedDir.exists()) {
      await generatedDir.create(recursive: true);
    }
    return generatedDir.path;
  }

  /// 생성된 이미지 목록 가져오기
  Future<List<String>> getGeneratedImages() async {
    try {
      final dir = await getGeneratedImagesDirectory();
      final directory = Directory(dir);
      if (!await directory.exists()) {
        return [];
      }

      final files = directory
          .listSync()
          .where((entity) => entity is File)
          .map((entity) => entity.path)
          .where(
            (path) =>
                path.endsWith('.png') ||
                path.endsWith('.jpg') ||
                path.endsWith('.jpeg'),
          )
          .toList();

      // 최신순 정렬
      files.sort((a, b) {
        final aTime = File(a).lastModifiedSync();
        final bTime = File(b).lastModifiedSync();
        return bTime.compareTo(aTime);
      });

      return files;
    } catch (e) {
      print('Error getting generated images: $e');
      return [];
    }
  }

  /// Auto Enhance: Real-ESRGAN AI 모델을 사용한 이미지 자동 향상
  Future<String?> autoEnhance(String imagePath) async {
    return await _aiService.autoEnhance(imagePath);
  }

  /// Upscale: Real-ESRGAN AI 모델을 사용한 해상도 향상
  Future<String?> upscale(String imagePath, {int scale = 2}) async {
    return await _aiService.upscale(imagePath, scale: scale);
  }

  /// Reduce Noise: Real-ESRGAN AI 모델을 사용한 노이즈 제거
  Future<String?> reduceNoise(String imagePath) async {
    return await _aiService.reduceNoise(imagePath);
  }

  /// Portrait Mode: GFPGAN/CodeFormer AI 모델을 사용한 얼굴 보정
  Future<String?> portraitMode(String imagePath) async {
    return await _aiService.portraitMode(imagePath);
  }

  /// Remove Background: 배경 제거 (MODNet AI 모델 사용)
  Future<String?> removeBackground(String imagePath) async {
    return await _aiService.removeBackground(imagePath);
  }

  /// Apply Filter: 이미지에 필터 적용
  Future<String?> applyFilter(String imagePath, String filterName) async {
    return await _aiService.applyFilter(imagePath, filterName);
  }

  /// Apply Adjustments: 이미지 조정 적용
  Future<String?> applyAdjustments(
    String imagePath,
    Map<String, double> adjustments,
  ) async {
    return await _aiService.applyAdjustments(imagePath, adjustments);
  }
}
