import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/ai_model_service.dart';
import '../services/image_service.dart';
import '../models/generation_config.dart';
import '../widgets/image_editor.dart';
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

    setState(() {
      _isGenerating = true;
    });

    try {
      final enhancedPath = await _imageService.autoEnhance(_selectedImagePath!);

      if (enhancedPath != null && mounted) {
        _applyResultImage(enhancedPath);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('자동 보정이 완료되었습니다. 되돌리기 버튼으로 이전 버전으로 돌아갈 수 있습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
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
  }

  Future<void> _performRemoveBackground() async {
    if (_selectedImagePath == null) {
      _showError('이미지를 선택해주세요.');
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final resultPath = await _imageService.removeBackground(
        _selectedImagePath!,
      );

      if (resultPath != null && mounted) {
        _applyResultImage(resultPath);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('배경 제거가 완료되었습니다. 되돌리기 버튼으로 이전 버전으로 돌아갈 수 있습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
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
  }

  void _showAIToolsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AIToolsSheet(
        onRemoveBackground: () {
          Navigator.pop(context);
          _performRemoveBackground();
        },
        onEnhance: () {
          Navigator.pop(context);
          _performAutoEnhance();
        },
        onPortraitMode: () {
          Navigator.pop(context);
          // TODO: Portrait mode 기능
        },
        onUpscale: () {
          Navigator.pop(context);
          // TODO: Upscale 기능
        },
        onReduceNoise: () {
          Navigator.pop(context);
          // TODO: Reduce noise 기능
        },
      ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
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
                                  Image.file(
                                    _selectedImageFile!,
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
                    _buildNavItem(Icons.tune, 'Adjust', 1, Colors.grey),
                    _buildNavItem(Icons.filter, 'Filters', 2, Colors.grey),
                    _buildNavItem(Icons.crop, 'Crop', 3, Colors.grey),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
