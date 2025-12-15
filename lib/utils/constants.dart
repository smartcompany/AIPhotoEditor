class AppConstants {
  // Model URLs
  static const String coreMLModelUrl = 
      'https://huggingface.co/apple/coreml-stable-diffusion-v1-5';
  
  // Model paths
  static const String modelCacheDir = 'models';
  static const String imageCacheDir = 'images';
  static const String generatedImagesDir = 'generated';
  
  // Image resolutions
  static const List<int> availableResolutions = [512, 768, 1024];
  static const int defaultResolution = 512;
  
  // Generation settings
  static const int defaultSteps = 20;
  static const double defaultGuidanceScale = 7.5;
  static const int defaultSeed = -1; // -1 means random
  
  // Platform Channel names
  static const String platformChannelName = 'com.aiphotoeditor/ai_model';
  
  // Method names
  static const String methodLoadModel = 'loadModel';
  static const String methodImageToImage = 'imageToImage';
  static const String methodInpaint = 'inpaint';
  static const String methodUnloadModel = 'unloadModel';
  static const String methodGetModelStatus = 'getModelStatus';
}

