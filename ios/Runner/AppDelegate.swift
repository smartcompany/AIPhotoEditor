import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let aiModelChannel = FlutterMethodChannel(
      name: "com.aiphotoeditor/ai_model",
      binaryMessenger: controller.binaryMessenger
    )
    
    let progressChannel = FlutterEventChannel(
      name: "com.aiphotoeditor/ai_model_progress",
      binaryMessenger: controller.binaryMessenger
    )
    
    let handler = AIModelHandler()
    handler.setupChannels(methodChannel: aiModelChannel, eventChannel: progressChannel)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
