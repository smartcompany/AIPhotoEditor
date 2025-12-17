import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/ai_model_service.dart';
import '../services/image_service.dart';
import '../services/model_download_service.dart';
import '../models/generation_config.dart';
import '../widgets/image_editor.dart';
import '../widgets/model_download_dialog.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _negativePromptController =
      TextEditingController();
  final AIModelService _aiService = AIModelService();
  final ImageService _imageService = ImageService();
  final ModelDownloadService _downloadService = ModelDownloadService();

  String? _selectedImagePath;
  File? _selectedImageFile;
  String? _maskImagePath;
  bool _isGenerating = false;
  bool _isModelLoaded = false;
  bool _isEditingMask = false;
  int _selectedTab = 0; // 0: AI Tools, 1: Adjust, 2: Filters, 3: Crop

  // 이미지 히스토리 (되돌리기/앞으로 가기 기능)
  String? _originalImagePath; // 원본 이미지
  List<String> _imageHistory = []; // 편집된 이미지들
  int _currentHistoryIndex = -1; // 현재 히스토리 위치 (-1은 최신 편집, -2는 원본)

  // 패널 상태
  bool _isAIToolsPanelVisible = false;
  bool _isAdjustmentsPanelVisible = false;
  bool _isFiltersPanelVisible = false;
  bool _isCropPanelVisible = false;

  // Adjustments 상태
  String? _selectedAdjustmentType; // 현재 선택된 조정 타입 (brightness, contrast, etc.)
  Map<String, double> _currentAdjustments = {};
  String? _previewImagePath; // 실시간 미리보기 이미지 경로
  Timer? _previewDebounceTimer;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    final loaded = await _aiService.isModelLoaded();
    setState(() {
      _isModelLoaded = loaded;
    });
  }

  Future<void> _pickImage() async {
    final imagePath = await _imageService.pickImage();
    if (imagePath != null) {
      setState(() {
        // 새 이미지를 선택하면 히스토리 초기화
        _originalImagePath = imagePath;
        _imageHistory.clear();
        _currentHistoryIndex = -2; // 원본 이미지 상태
        _selectedImagePath = imagePath;
        _selectedImageFile = File(imagePath);
        _maskImagePath = null;
        _isEditingMask = false;
      });
    }
  }

  void _applyResultImage(String resultPath) {
    setState(() {
      // 현재 위치 이후의 히스토리 제거 (분기된 히스토리 제거)
      if (_currentHistoryIndex >= 0) {
        _imageHistory = _imageHistory.sublist(0, _currentHistoryIndex + 1);
      }
      // 원본에서 새 편집을 시작하는 경우, 히스토리를 유지하고 새 편집 추가
      // (히스토리를 초기화하지 않음 - 버튼이 사라지는 버그 방지)

      // 새 결과 이미지를 히스토리에 추가
      _imageHistory.add(resultPath);
      _currentHistoryIndex = _imageHistory.length - 1; // 최신 편집 상태

      // 결과 이미지로 교체
      _selectedImagePath = resultPath;
      _selectedImageFile = File(resultPath);
      // 마스크 초기화 (새 이미지에 적용)
      _maskImagePath = null;
    });
  }

  void _undoImage() {
    if (_currentHistoryIndex > 0) {
      // 이전 편집으로 이동
      setState(() {
        _currentHistoryIndex--;
        _selectedImagePath = _imageHistory[_currentHistoryIndex];
        _selectedImageFile = File(_selectedImagePath!);
        _maskImagePath = null;
      });
    } else if (_currentHistoryIndex == 0) {
      // 원본 이미지로 이동
      setState(() {
        _currentHistoryIndex = -2;
        if (_originalImagePath != null) {
          _selectedImagePath = _originalImagePath;
          _selectedImageFile = File(_originalImagePath!);
        }
        _maskImagePath = null;
      });
    }
  }

  void _redoImage() {
    if (_currentHistoryIndex == -2 && _imageHistory.isNotEmpty) {
      // 원본에서 첫 번째 편집으로 이동
      setState(() {
        _currentHistoryIndex = 0;
        _selectedImagePath = _imageHistory[0];
        _selectedImageFile = File(_imageHistory[0]);
        _maskImagePath = null;
      });
    } else if (_currentHistoryIndex >= 0 &&
        _currentHistoryIndex < _imageHistory.length - 1) {
      // 다음 편집으로 이동
      setState(() {
        _currentHistoryIndex++;
        _selectedImagePath = _imageHistory[_currentHistoryIndex];
        _selectedImageFile = File(_selectedImagePath!);
        _maskImagePath = null;
      });
    }
  }

  bool get _canUndo {
    // 되돌리기 가능: 편집 히스토리가 있고, 원본이 아니거나 이전 편집이 있음
    if (_imageHistory.isEmpty) return false;
    // 원본이 아니면 되돌리기 가능
    return _currentHistoryIndex != -2;
  }

  bool get _canRedo {
    // 앞으로 가기 가능: 원본에서 편집이 있거나, 히스토리 중간에 있음
    if (_imageHistory.isEmpty) return false;
    // 원본이거나, 최신 편집이 아니면 앞으로 가기 가능
    return _currentHistoryIndex == -2 ||
        (_currentHistoryIndex >= 0 &&
            _currentHistoryIndex < _imageHistory.length - 1);
  }

  Future<void> _removeImage() async {
    if (_selectedImagePath != null) {
      await _imageService.deleteImage(_selectedImagePath!);
      if (_maskImagePath != null) {
        await _imageService.deleteImage(_maskImagePath!);
      }
      setState(() {
        _selectedImagePath = null;
        _selectedImageFile = null;
        _maskImagePath = null;
        _isEditingMask = false;
      });
    }
  }

  void _startEditingMask() {
    if (_selectedImageFile != null) {
      setState(() {
        _isEditingMask = true;
      });
    }
  }

  void _onMaskCreated(String maskPath) {
    setState(() {
      _maskImagePath = maskPath;
      _isEditingMask = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('마스크가 생성되었습니다. AI Tools에서 편집을 시작하세요.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _generateImage() async {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    if (_maskImagePath == null) {
      _showError('편집할 영역을 선택해주세요.');
      return;
    }

    if (_promptController.text.trim().isEmpty) {
      _showError('프롬프트를 입력해주세요.');
      return;
    }

    if (!_isModelLoaded) {
      _showError('모델이 로드되지 않았습니다. 설정에서 모델을 다운로드해주세요.');
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final imageBytes = await _selectedImageFile!.readAsBytes();
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;

      final config = GenerationConfig(
        prompt: _promptController.text.trim(),
        negativePrompt: _negativePromptController.text.trim().isEmpty
            ? null
            : _negativePromptController.text.trim(),
        width: width,
        height: height,
        inputImagePath: _selectedImagePath,
        maskImagePath: _maskImagePath,
        type: GenerationType.inpaint,
      );

      final resultPath = await _aiService.inpaint(config);

      if (resultPath != null && mounted) {
        _applyResultImage(resultPath);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('편집이 완료되었습니다. 되돌리기 버튼으로 이전 버전으로 돌아갈 수 있습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        _showError('이미지 생성에 실패했습니다.');
      }
    } catch (e) {
      _showError('오류 발생: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _performAutoEnhance() async {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    // 모델 다운로드 진행도 표시
    await _showDownloadDialogIfNeeded('realesrgan_x2plus', () async {
      setState(() {
        _isGenerating = true;
      });

      try {
        final enhancedPath = await _imageService.autoEnhance(
          _selectedImagePath!,
        );

        if (enhancedPath != null && mounted) {
          _applyResultImage(enhancedPath);
        } else {
          _showError('이미지 보정에 실패했습니다.');
        }
      } catch (e) {
        _showError('오류 발생: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isGenerating = false;
          });
        }
      }
    });
  }

  Future<void> _performPortraitMode() async {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final resultPath = await _imageService.portraitMode(_selectedImagePath!);

      if (resultPath != null && mounted) {
        _applyResultImage(resultPath);
      } else {
        _showError('Portrait Mode 적용에 실패했습니다.');
      }
    } catch (e) {
      _showError('오류 발생: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _performRemoveBackground() async {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    // 모델 다운로드 진행도 표시
    await _showDownloadDialogIfNeeded('modnet', () async {
      setState(() {
        _isGenerating = true;
      });

      try {
        final resultPath = await _imageService.removeBackground(
          _selectedImagePath!,
        );

        if (resultPath != null && mounted) {
          _applyResultImage(resultPath);
        } else {
          _showError('배경 제거에 실패했습니다.');
        }
      } catch (e) {
        _showError('오류 발생: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isGenerating = false;
          });
        }
      }
    });
  }

  Future<void> _performRemove() async {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    // TODO: Remove 기능 구현
    _showError('Remove 기능은 아직 구현 중입니다.');
  }

  Future<void> _performUpscale() async {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    // 모델 다운로드 진행도 표시
    await _showDownloadDialogIfNeeded('realesrgan_x2plus', () async {
      setState(() {
        _isGenerating = true;
      });

      try {
        final resultPath = await _imageService.upscale(
          _selectedImagePath!,
          scale: 2,
        );

        if (resultPath != null && mounted) {
          _applyResultImage(resultPath);
        } else {
          _showError('해상도 향상에 실패했습니다.');
        }
      } catch (e) {
        _showError('오류 발생: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isGenerating = false;
          });
        }
      }
    });
  }

  Future<void> _performReduceNoise() async {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    // 모델 다운로드 진행도 표시
    await _showDownloadDialogIfNeeded('realesrgan_x2plus', () async {
      setState(() {
        _isGenerating = true;
      });

      try {
        final resultPath = await _imageService.reduceNoise(_selectedImagePath!);

        if (resultPath != null && mounted) {
          _applyResultImage(resultPath);
        } else {
          _showError('노이즈 제거에 실패했습니다.');
        }
      } catch (e) {
        _showError('오류 발생: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isGenerating = false;
          });
        }
      }
    });
  }

  Future<void> _applyFilter(String filterName) async {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final resultPath = await _imageService.applyFilter(
        _selectedImagePath!,
        filterName,
      );

      if (resultPath != null && mounted) {
        _applyResultImage(resultPath);
      } else {
        _showError('필터 적용에 실패했습니다.');
      }
    } catch (e) {
      _showError('오류 발생: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _applyAdjustments(Map<String, double> adjustments) async {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final resultPath = await _imageService.applyAdjustments(
        _selectedImagePath!,
        adjustments,
      );

      if (resultPath != null && mounted) {
        _applyResultImage(resultPath);
      } else {
        _showError('조정 적용에 실패했습니다.');
      }
    } catch (e) {
      _showError('오류 발생: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  /// 모델 다운로드 다이얼로그 표시 (필요한 경우)
  Future<void> _showDownloadDialogIfNeeded(
    String modelName,
    Future<void> Function() onComplete,
  ) async {
    // 진행도 스트림 구독
    final progressStream = _downloadService.getProgressStream();

    // 다이얼로그 표시
    bool dialogShown = false;
    bool downloadComplete = false;
    StreamSubscription<ModelDownloadProgress>? subscription;

    // 진행도 스트림 리스너
    subscription = progressStream.listen(
      (progress) {
        // 해당 모델의 진행도만 표시
        if (progress.modelName == modelName) {
          if (!dialogShown && mounted) {
            dialogShown = true;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => ModelDownloadDialog(
                modelName: modelName,
                progressStream: progressStream,
              ),
            ).then((_) {
              downloadComplete = true;
              subscription?.cancel();
              onComplete();
            });
          }

          // 다운로드 완료 확인
          if (progress.progress >= 1.0 && dialogShown && !downloadComplete) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
                downloadComplete = true;
                subscription?.cancel();
                onComplete();
              }
            });
          }
        }
      },
      onError: (error) {
        if (mounted && dialogShown && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        subscription?.cancel();
        _showError('모델 다운로드 실패: $error');
      },
    );

    // 다이얼로그가 표시되지 않으면 바로 실행 (모델이 이미 있는 경우)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!dialogShown && !downloadComplete) {
        subscription?.cancel();
        onComplete();
      }
    });
  }

  void _showAIToolsSheet() {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    setState(() {
      _isAIToolsPanelVisible = true;
      _isAdjustmentsPanelVisible = false;
      _isFiltersPanelVisible = false;
      _isCropPanelVisible = false;
    });
  }

  void _showAdjustmentsSheet() {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    setState(() {
      _isAIToolsPanelVisible = false;
      _isAdjustmentsPanelVisible = true;
      _isFiltersPanelVisible = false;
      _isCropPanelVisible = false;
      _selectedAdjustmentType = 'brightness'; // 기본값
      _currentAdjustments = {};
      _previewImagePath = null;
    });
  }

  void _hideAdjustmentsPanel() {
    setState(() {
      _isAdjustmentsPanelVisible = false;
      _selectedAdjustmentType = null;
      _currentAdjustments = {};
      _previewImagePath = null;
    });
  }

  Future<void> _updatePreview(Map<String, double> adjustments) async {
    if (_selectedImagePath == null) return;

    setState(() {
      _currentAdjustments = adjustments;
    });

    // Debounce: 300ms 후에 미리보기 업데이트
    _previewDebounceTimer?.cancel();
    _previewDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final resultPath = await _imageService.applyAdjustments(
          _selectedImagePath!,
          adjustments,
        );

        if (resultPath != null && mounted) {
          setState(() {
            _previewImagePath = resultPath;
          });
        }
      } catch (e) {
        print('Preview 업데이트 실패: $e');
      }
    });
  }

  void _showFiltersSheet() {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    setState(() {
      _isAIToolsPanelVisible = false;
      _isAdjustmentsPanelVisible = false;
      _isFiltersPanelVisible = true;
      _isCropPanelVisible = false;
    });
  }

  void _showCropSheet() {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    setState(() {
      _isAIToolsPanelVisible = false;
      _isAdjustmentsPanelVisible = false;
      _isFiltersPanelVisible = false;
      _isCropPanelVisible = true;
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
    _previewDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditingMask && _selectedImageFile != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Photo'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _isEditingMask = false;
              });
            },
          ),
        ),
        body: ImageEditor(
          imageFile: _selectedImageFile!,
          onMaskCreated: _onMaskCreated,
        ),
      );
    }

    if (_selectedImageFile == null) {
      return _buildUploadScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Photo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _removeImage(),
        ),
        actions: [
          // 되돌리기 버튼
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _canUndo ? _undoImage : null,
            tooltip: '이전 버전으로 되돌리기',
          ),
          // 앞으로 가기 버튼
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _canRedo ? _redoImage : null,
            tooltip: '다음 버전으로 앞으로 가기',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              if (_selectedImagePath != null) {
                final success = await _imageService.saveToGallery(
                  _selectedImagePath!,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '갤러리에 저장되었습니다' : '저장에 실패했습니다'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            tooltip: '갤러리에 저장',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _checkModelStatus());
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 이미지 표시 영역
          Column(
            children: [
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      Center(
                        child: _selectedImageFile != null
                            ? Stack(
                                children: [
                                  // 미리보기 이미지가 있으면 표시, 없으면 원본
                                  Image.file(
                                    _previewImagePath != null
                                        ? File(_previewImagePath!)
                                        : _selectedImageFile!,
                                    fit: BoxFit.contain,
                                  ),
                                  if (_maskImagePath != null)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.red.withOpacity(0.2),
                                      ),
                                    ),
                                ],
                              )
                            : const Icon(
                                Icons.upload,
                                size: 80,
                                color: Colors.white54,
                              ),
                      ),
                      // 생성 중 로딩 오버레이
                      if (_isGenerating)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '처리 중...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Adjustments Panel (사진 아래 고정)
              if (_isAdjustmentsPanelVisible)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 조정 타입 선택 버튼들
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildAdjustmentTypeButton(
                            'brightness',
                            Icons.wb_sunny,
                            'Brightness',
                          ),
                          _buildAdjustmentTypeButton(
                            'contrast',
                            Icons.contrast,
                            'Contrast',
                          ),
                          _buildAdjustmentTypeButton(
                            'saturation',
                            Icons.palette,
                            'Saturation',
                          ),
                          _buildAdjustmentTypeButton(
                            'blur',
                            Icons.blur_on,
                            'Blur',
                          ),
                          _buildAdjustmentTypeButton(
                            'sharpen',
                            Icons.center_focus_strong,
                            'Sharpen',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // 선택된 조정의 슬라이더
                      if (_selectedAdjustmentType != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildAdjustmentSliderForType(
                            _selectedAdjustmentType!,
                          ),
                        ),
                      const SizedBox(height: 10),
                      // Apply 및 Reset 버튼
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                _hideAdjustmentsPanel();
                                if (_originalImagePath != null) {
                                  _applyResultImage(_originalImagePath!);
                                }
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _hideAdjustmentsPanel();
                                _applyAdjustments(_currentAdjustments);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Apply'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // AI Tools Panel (사진 아래 고정)
              if (_isAIToolsPanelVisible)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // AI 도구 버튼들
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            _buildAIToolButton(
                              Icons.auto_fix_high,
                              'Auto Enhance',
                              _performAutoEnhance,
                            ),
                            const SizedBox(width: 12),
                            _buildAIToolButton(
                              Icons.face,
                              'Portrait',
                              _performPortraitMode,
                            ),
                            const SizedBox(width: 12),
                            _buildAIToolButton(
                              Icons.content_cut,
                              'Remove BG',
                              _performRemoveBackground,
                            ),
                            const SizedBox(width: 12),
                            _buildAIToolButton(
                              Icons.cleaning_services,
                              'Remove',
                              _performRemove,
                            ),
                            const SizedBox(width: 12),
                            _buildAIToolButton(
                              Icons.flash_on,
                              'Denoise',
                              _performReduceNoise,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tap a tool to apply AI enhancements',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              // Filters Panel (사진 아래 고정)
              if (_isFiltersPanelVisible)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 필터 미리보기
                      SizedBox(
                        height: 120,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _buildFilterPreview('Original', Colors.grey),
                            const SizedBox(width: 12),
                            _buildFilterPreview('Vivid', Colors.pink),
                            const SizedBox(width: 12),
                            _buildFilterPreview('Dramatic', Colors.purple),
                            const SizedBox(width: 12),
                            _buildFilterPreview('Mono', Colors.grey.shade600),
                            const SizedBox(width: 12),
                            _buildFilterPreview('Silver', Colors.grey.shade400),
                            const SizedBox(width: 12),
                            _buildFilterPreview('Noir', Colors.black87),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tap a filter to preview',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              // Crop Panel (사진 아래 고정)
              if (_isCropPanelVisible)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Crop 기능은 아직 구현 중입니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              // 하단 네비게이션 바
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      Icons.auto_awesome,
                      'AI Tools',
                      0,
                      Colors.purple,
                    ),
                    _buildNavItem(Icons.tune, 'Adjust', 1, Colors.purple),
                    _buildNavItem(Icons.filter, 'Filters', 2, Colors.purple),
                    _buildNavItem(Icons.crop, 'Crop', 3, Colors.purple),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIToolButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.purple, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPreview(String filterName, Color color) {
    return GestureDetector(
      onTap: () {
        _applyFilter(filterName);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filterName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentTypeButton(String type, IconData icon, String label) {
    final isSelected = _selectedAdjustmentType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAdjustmentType = type;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSelected ? Colors.purple : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade700,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.purple : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentSliderForType(String type) {
    final currentValue = _currentAdjustments[type] ?? 0.0;
    double min, max;
    String label;

    switch (type) {
      case 'brightness':
        min = -1.0;
        max = 1.0;
        label = 'Brightness';
        break;
      case 'contrast':
        min = -1.0;
        max = 1.0;
        label = 'Contrast';
        break;
      case 'saturation':
        min = -1.0;
        max = 1.0;
        label = 'Saturation';
        break;
      case 'blur':
        min = 0.0;
        max = 10.0;
        label = 'Blur';
        break;
      case 'sharpen':
        min = 0.0;
        max = 2.0;
        label = 'Sharpen';
        break;
      default:
        min = -1.0;
        max = 1.0;
        label = type;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              currentValue.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: currentValue,
          min: min,
          max: max,
          onChanged: (value) {
            final newAdjustments = Map<String, double>.from(
              _currentAdjustments,
            );
            newAdjustments[type] = value;
            setState(() {
              _currentAdjustments = newAdjustments;
            });
            _updatePreview(newAdjustments);
          },
          activeColor: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, Color color) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
        if (index == 0) {
          _showAIToolsSheet();
        } else if (index == 1) {
          _showAdjustmentsSheet();
        } else if (index == 2) {
          _showFiltersSheet();
        } else if (index == 3) {
          _showCropSheet();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Photo Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _checkModelStatus());
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            // 제목
            const Text(
              'Upload a Photo',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a photo to start editing',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 60),
            // 업로드 아이콘
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 60,
                  color: Colors.purple.shade300,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // 업로드 버튼
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text(
                'Choose Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// AI Tools 모달 시트
class _AIToolsSheet extends StatelessWidget {
  final VoidCallback onRemoveBackground;
  final VoidCallback onEnhance;
  final VoidCallback onPortraitMode;
  final VoidCallback onUpscale;
  final VoidCallback onReduceNoise;

  const _AIToolsSheet({
    required this.onRemoveBackground,
    required this.onEnhance,
    required this.onPortraitMode,
    required this.onUpscale,
    required this.onReduceNoise,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 핸들
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AI Tools',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // 도구 리스트
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildToolCard(
                      icon: Icons.auto_fix_high,
                      iconColor: Colors.purple,
                      title: 'Auto Enhance',
                      description: 'Improve colors, brightness, and sharpness',
                      onApply: onEnhance,
                    ),
                    const SizedBox(height: 16),
                    _buildToolCard(
                      icon: Icons.face,
                      iconColor: Colors.pink,
                      title: 'Portrait Mode',
                      description: 'Smooth skin and enhance facial features',
                      onApply: onPortraitMode,
                    ),
                    const SizedBox(height: 16),
                    _buildToolCard(
                      icon: Icons.content_cut,
                      iconColor: Colors.lightBlue,
                      title: 'Remove Background',
                      description: 'Intelligently remove background',
                      onApply: onRemoveBackground,
                    ),
                    const SizedBox(height: 16),
                    _buildToolCard(
                      icon: Icons.zoom_in,
                      iconColor: Colors.green,
                      title: 'AI Upscale',
                      description: 'Increase resolution with AI',
                      onApply: onUpscale,
                    ),
                    const SizedBox(height: 16),
                    _buildToolCard(
                      icon: Icons.flash_on,
                      iconColor: Colors.orange,
                      title: 'Reduce Noise',
                      description: 'Remove grain while keeping details',
                      onApply: onReduceNoise,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onApply,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: onApply,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

// Adjustments Floating Panel
class _AdjustmentsFloatingPanel extends StatefulWidget {
  final Function(String, double) onAdjustmentChanged;
  final Function(Map<String, double>) onApply;
  final VoidCallback onReset;
  final VoidCallback onClose;
  final Function(Offset) onPositionChanged;
  final Offset initialPosition;

  const _AdjustmentsFloatingPanel({
    required this.onAdjustmentChanged,
    required this.onApply,
    required this.onReset,
    required this.onClose,
    required this.onPositionChanged,
    required this.initialPosition,
  });

  @override
  State<_AdjustmentsFloatingPanel> createState() =>
      _AdjustmentsFloatingPanelState();
}

class _AdjustmentsFloatingPanelState extends State<_AdjustmentsFloatingPanel> {
  late Offset _position;
  double _brightness = 0.0;
  double _contrast = 0.0;
  double _saturation = 0.0;
  double _blur = 0.0;
  double _sharpen = 0.0;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = screenSize.width * 0.9;
    final maxHeight = screenSize.height * 0.7;

    return Positioned(
      left: _position.dx.clamp(0.0, screenSize.width - maxWidth),
      top: _position.dy.clamp(0.0, screenSize.height - maxHeight),
      child: Draggable(
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: maxWidth,
            height: maxHeight,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
          ),
        ),
        onDragEnd: (details) {
          final newPosition = Offset(
            details.offset.dx.clamp(0.0, screenSize.width - maxWidth),
            details.offset.dy.clamp(0.0, screenSize.height - maxHeight),
          );
          setState(() {
            _position = newPosition;
          });
          widget.onPositionChanged(newPosition);
        },
        childWhenDragging: Container(
          width: maxWidth,
          height: maxHeight,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: maxWidth,
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 드래그 핸들 및 헤더
                  GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _position = Offset(
                          (_position.dx + details.delta.dx).clamp(
                            0.0,
                            screenSize.width - maxWidth,
                          ),
                          (_position.dy + details.delta.dy).clamp(
                            0.0,
                            screenSize.height - maxHeight,
                          ),
                        );
                      });
                      widget.onPositionChanged(_position);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Adjustments',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: widget.onReset,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Reset'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: widget.onClose,
                                color: Colors.black87,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  // 조정 옵션 리스트
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildAdjustmentSlider(
                            'Brightness',
                            _brightness,
                            -1.0,
                            1.0,
                            (value) {
                              setState(() {
                                _brightness = value;
                              });
                              widget.onAdjustmentChanged('brightness', value);
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildAdjustmentSlider(
                            'Contrast',
                            _contrast,
                            -1.0,
                            1.0,
                            (value) {
                              setState(() {
                                _contrast = value;
                              });
                              widget.onAdjustmentChanged('contrast', value);
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildAdjustmentSlider(
                            'Saturation',
                            _saturation,
                            -1.0,
                            1.0,
                            (value) {
                              setState(() {
                                _saturation = value;
                              });
                              widget.onAdjustmentChanged('saturation', value);
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildAdjustmentSlider('Blur', _blur, 0.0, 10.0, (
                            value,
                          ) {
                            setState(() {
                              _blur = value;
                            });
                            widget.onAdjustmentChanged('blur', value);
                          }),
                          const SizedBox(height: 20),
                          _buildAdjustmentSlider(
                            'Sharpen',
                            _sharpen,
                            0.0,
                            2.0,
                            (value) {
                              setState(() {
                                _sharpen = value;
                              });
                              widget.onAdjustmentChanged('sharpen', value);
                            },
                          ),
                          const SizedBox(height: 20),
                          // Apply 버튼
                          ElevatedButton(
                            onPressed: () {
                              widget.onApply({
                                'brightness': _brightness,
                                'contrast': _contrast,
                                'saturation': _saturation,
                                'blur': _blur,
                                'sharpen': _sharpen,
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 32,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustmentSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              value.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: Colors.purple,
        ),
      ],
    );
  }
}

// Adjustments 모달 시트
class _AdjustmentsSheet extends StatefulWidget {
  final Function(String, double) onAdjustmentChanged;
  final Function(Map<String, double>) onApply;
  final VoidCallback onReset;

  const _AdjustmentsSheet({
    required this.onAdjustmentChanged,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_AdjustmentsSheet> createState() => _AdjustmentsSheetState();
}

class _AdjustmentsSheetState extends State<_AdjustmentsSheet> {
  double _brightness = 0.0;
  double _contrast = 0.0;
  double _saturation = 0.0;
  double _blur = 0.0;
  double _sharpen = 0.0;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // 핸들
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 헤더
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Adjustments',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: widget.onReset,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Reset'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // 조정 옵션 리스트
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildAdjustmentSlider(
                          'Brightness',
                          _brightness,
                          -1.0,
                          1.0,
                          (value) {
                            setState(() {
                              _brightness = value;
                            });
                            widget.onAdjustmentChanged('brightness', value);
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildAdjustmentSlider(
                          'Contrast',
                          _contrast,
                          -1.0,
                          1.0,
                          (value) {
                            setState(() {
                              _contrast = value;
                            });
                            widget.onAdjustmentChanged('contrast', value);
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildAdjustmentSlider(
                          'Saturation',
                          _saturation,
                          -1.0,
                          1.0,
                          (value) {
                            setState(() {
                              _saturation = value;
                            });
                            widget.onAdjustmentChanged('saturation', value);
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildAdjustmentSlider('Blur', _blur, 0.0, 10.0, (
                          value,
                        ) {
                          setState(() {
                            _blur = value;
                          });
                          widget.onAdjustmentChanged('blur', value);
                        }),
                        const SizedBox(height: 24),
                        _buildAdjustmentSlider('Sharpen', _sharpen, 0.0, 2.0, (
                          value,
                        ) {
                          setState(() {
                            _sharpen = value;
                          });
                          widget.onAdjustmentChanged('sharpen', value);
                        }),
                        const SizedBox(height: 32),
                        // Apply 버튼
                        ElevatedButton(
                          onPressed: () {
                            widget.onApply({
                              'brightness': _brightness,
                              'contrast': _contrast,
                              'saturation': _saturation,
                              'blur': _blur,
                              'sharpen': _sharpen,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdjustmentSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: Colors.purple,
        ),
      ],
    );
  }
}

// Filters 모달 시트
class _FiltersSheet extends StatelessWidget {
  final Function(String) onFilterSelected;

  const _FiltersSheet({required this.onFilterSelected});

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'name': 'Original', 'icon': Icons.filter_none, 'color': Colors.grey},
      {'name': 'Vivid', 'icon': Icons.color_lens, 'color': Colors.pink},
      {'name': 'Dramatic', 'icon': Icons.auto_awesome, 'color': Colors.purple},
      {'name': 'Warm', 'icon': Icons.wb_sunny, 'color': Colors.orange},
      {'name': 'Cool', 'icon': Icons.ac_unit, 'color': Colors.blue},
      {'name': 'Vintage', 'icon': Icons.camera_alt, 'color': Colors.brown},
      {'name': 'B&W', 'icon': Icons.tonality, 'color': Colors.black},
      {'name': 'Cinematic', 'icon': Icons.movie, 'color': Colors.indigo},
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 핸들
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // 필터 그리드
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: filters.length,
                  itemBuilder: (context, index) {
                    final filter = filters[index];
                    return GestureDetector(
                      onTap: () => onFilterSelected(filter['name'] as String),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              filter['icon'] as IconData,
                              color: filter['color'] as Color,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              filter['name'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 프롬프트 입력 다이얼로그
class _PromptDialog extends StatelessWidget {
  final TextEditingController promptController;
  final TextEditingController negativePromptController;
  final VoidCallback onGenerate;
  final bool isGenerating;

  const _PromptDialog({
    required this.promptController,
    required this.negativePromptController,
    required this.onGenerate,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'AI Edit',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                '프롬프트',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: promptController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '예: remove the person, add flowers',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '네거티브 프롬프트 (선택)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: negativePromptController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: '예: blurry, low quality',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isGenerating ? null : onGenerate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: isGenerating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Generate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
