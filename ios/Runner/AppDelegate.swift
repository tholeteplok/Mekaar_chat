import Flutter
import UIKit

private final class ScreenCaptureStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var observer: NSObjectProtocol?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    events(UIScreen.main.isCaptured)
    observer = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.eventSink?(UIScreen.main.isCaptured)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
    eventSink = nil
    return nil
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let captureHandler = ScreenCaptureStreamHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "MekaarScreenCapture"
    )
    let channel = FlutterEventChannel(
      name: "com.mekaar.mekaar_chat/screen_capture",
      binaryMessenger: registrar.messenger()
    )
    channel.setStreamHandler(captureHandler)
  }
}
