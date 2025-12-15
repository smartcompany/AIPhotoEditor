class GenerationConfig {
  final String prompt;
  final String? negativePrompt;
  final int steps;
  final double guidanceScale;
  final int seed;
  final int width;
  final int height;
  final String? inputImagePath;
  final String? maskImagePath;
  final GenerationType type;

  GenerationConfig({
    required this.prompt,
    this.negativePrompt,
    this.steps = 20,
    this.guidanceScale = 7.5,
    this.seed = -1,
    this.width = 512,
    this.height = 512,
    this.inputImagePath,
    this.maskImagePath,
    this.type = GenerationType.imageToImage,
  });

  Map<String, dynamic> toMap() {
    return {
      'prompt': prompt,
      'negativePrompt': negativePrompt ?? '',
      'steps': steps,
      'guidanceScale': guidanceScale,
      'seed': seed,
      'width': width,
      'height': height,
      'inputImagePath': inputImagePath ?? '',
      'maskImagePath': maskImagePath ?? '',
      'type': type.toString().split('.').last,
    };
  }
}

enum GenerationType {
  imageToImage,
  inpaint,
}

