import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 이미지 위에 마스크를 그릴 수 있는 위젯
class ImageEditor extends StatefulWidget {
  final File imageFile;
  final Function(String maskPath) onMaskCreated;

  const ImageEditor({
    super.key,
    required this.imageFile,
    required this.onMaskCreated,
  });

  @override
  State<ImageEditor> createState() => _ImageEditorState();
}

class _ImageEditorState extends State<ImageEditor> {
  final GlobalKey _imageKey = GlobalKey();
  List<Offset> _maskPoints = [];
  bool _isDrawing = false;
  double _brushSize = 20.0;
  ui.Image? _image;
  Size? _imageSize;
  Size? _displaySize;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final imageBytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _image = frame.image;
      _imageSize = Size(_image!.width.toDouble(), _image!.height.toDouble());
    });
  }

  void _clearMask() {
    setState(() {
      _maskPoints.clear();
    });
  }

  void _increaseBrushSize() {
    setState(() {
      _brushSize = (_brushSize + 5).clamp(5.0, 50.0);
    });
  }

  void _decreaseBrushSize() {
    setState(() {
      _brushSize = (_brushSize - 5).clamp(5.0, 50.0);
    });
  }

  Future<String> _saveMask() async {
    if (_image == null || _maskPoints.isEmpty) {
      throw Exception('이미지가 로드되지 않았거나 마스크가 없습니다');
    }

    // 마스크 이미지 생성
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 검은 배경 (투명한 부분)
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _imageSize!.width, _imageSize!.height),
      paint,
    );

    // 흰색으로 마스크 영역 그리기
    final maskPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (var point in _maskPoints) {
      // 이미지 좌표로 변환
      final imagePoint = _displayToImagePoint(point);
      canvas.drawCircle(
        imagePoint,
        _brushSize * (_imageSize!.width / _displaySize!.width),
        maskPaint,
      );
    }

    // 마스크를 이미지로 변환
    final picture = recorder.endRecording();
    final maskImage = await picture.toImage(
      _imageSize!.width.toInt(),
      _imageSize!.height.toInt(),
    );

    // PNG로 저장
    final byteData = await maskImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('마스크 저장 실패');
    }

    final maskPath = '${widget.imageFile.path}_mask.png';
    final maskFile = File(maskPath);
    await maskFile.writeAsBytes(byteData.buffer.asUint8List());

    return maskPath;
  }

  Offset _displayToImagePoint(Offset displayPoint) {
    if (_image == null || _imageSize == null || _displaySize == null) {
      return displayPoint;
    }

    // 이미지 비율 계산 (ImageMaskPainter와 동일한 로직)
    final imageAspectRatio = _imageSize!.width / _imageSize!.height;
    final canvasAspectRatio = _displaySize!.width / _displaySize!.height;

    Rect imageRect;
    if (imageAspectRatio > canvasAspectRatio) {
      final height = _displaySize!.width / imageAspectRatio;
      imageRect = Rect.fromLTWH(
        0,
        (_displaySize!.height - height) / 2,
        _displaySize!.width,
        height,
      );
    } else {
      final width = _displaySize!.height * imageAspectRatio;
      imageRect = Rect.fromLTWH(
        (_displaySize!.width - width) / 2,
        0,
        width,
        _displaySize!.height,
      );
    }

    // 이미지 영역 내의 상대 좌표로 변환
    final relativeX = (displayPoint.dx - imageRect.left) / imageRect.width;
    final relativeY = (displayPoint.dy - imageRect.top) / imageRect.height;

    // 원본 이미지 좌표로 변환
    return Offset(
      relativeX * _imageSize!.width,
      relativeY * _imageSize!.height,
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDrawing = true;
      _maskPoints.add(details.localPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isDrawing) {
      setState(() {
        _maskPoints.add(details.localPosition);
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDrawing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 브러시 크기 조절 및 지우기 버튼
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.black87,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white),
                onPressed: _decreaseBrushSize,
                tooltip: '브러시 크기 감소',
              ),
              Text(
                '브러시: ${_brushSize.toInt()}px',
                style: const TextStyle(color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: _increaseBrushSize,
                tooltip: '브러시 크기 증가',
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white),
                onPressed: _clearMask,
                tooltip: '마스크 지우기',
              ),
            ],
          ),
        ),

        // 이미지 및 마스크 표시
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  key: _imageKey,
                  size: Size.infinite,
                  painter: ImageMaskPainter(
                    image: _image!,
                    maskPoints: _maskPoints,
                    brushSize: _brushSize,
                    constraints: constraints,
                    onSizeChanged: (size) {
                      if (mounted) {
                        setState(() {
                          _displaySize = size;
                        });
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),

        // 저장 버튼
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _maskPoints.isEmpty
                ? null
                : () async {
                    try {
                      final maskPath = await _saveMask();
                      widget.onMaskCreated(maskPath);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('마스크 저장 실패: $e')),
                        );
                      }
                    }
                  },
            icon: const Icon(Icons.check),
            label: const Text('마스크 완료'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class ImageMaskPainter extends CustomPainter {
  final ui.Image image;
  final List<Offset> maskPoints;
  final double brushSize;
  final BoxConstraints constraints;
  final Function(Size) onSizeChanged;

  ImageMaskPainter({
    required this.image,
    required this.maskPoints,
    required this.brushSize,
    required this.constraints,
    required this.onSizeChanged,
  });

  Rect _calculateImageRect(Size canvasSize) {
    // 이미지 비율 계산
    final imageAspectRatio = image.width / image.height;
    final canvasAspectRatio = canvasSize.width / canvasSize.height;

    if (imageAspectRatio > canvasAspectRatio) {
      // 이미지가 더 넓음 - 너비에 맞춤
      final height = canvasSize.width / imageAspectRatio;
      return Rect.fromLTWH(
        0,
        (canvasSize.height - height) / 2,
        canvasSize.width,
        height,
      );
    } else {
      // 이미지가 더 높음 - 높이에 맞춤
      final width = canvasSize.height * imageAspectRatio;
      return Rect.fromLTWH(
        (canvasSize.width - width) / 2,
        0,
        width,
        canvasSize.height,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    onSizeChanged(size);

    // 이미지 영역 계산
    final imageRect = _calculateImageRect(size);

    // 이미지 그리기
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      imageRect,
      Paint(),
    );

    // 마스크 영역 표시 (반투명 빨간색)
    final maskPaint = Paint()
      ..color = Colors.red.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    for (var point in maskPoints) {
      // 이미지 영역 내에 있는지 확인
      if (imageRect.contains(point)) {
        canvas.drawCircle(point, brushSize, maskPaint);
      }
    }

    // 마스크 경계선
    final borderPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var point in maskPoints) {
      // 이미지 영역 내에 있는지 확인
      if (imageRect.contains(point)) {
        canvas.drawCircle(point, brushSize, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(ImageMaskPainter oldDelegate) {
    return image != oldDelegate.image ||
        maskPoints.length != oldDelegate.maskPoints.length ||
        brushSize != oldDelegate.brushSize;
  }
}
