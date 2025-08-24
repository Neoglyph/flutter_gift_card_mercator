import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let cameraChannel = FlutterMethodChannel(name: "camera_permissions",
                                           binaryMessenger: controller.binaryMessenger)
    
    cameraChannel.setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "checkCameraPermission":
        let status = self.checkCameraPermission()
        result(status)
      case "requestCameraPermission":
        self.requestCameraPermission { status in
          result(status)
        }
      case "openAppSettings":
        self.openAppSettings()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Camera Permission Methods
  
  private func checkCameraPermission() -> String {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    
    switch status {
    case .authorized:
      return "authorized"
    case .notDetermined:
      return "notDetermined"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    @unknown default:
      return "notDetermined"
    }
  }
  
  private func requestCameraPermission(completion: @escaping (String) -> Void) {
    AVCaptureDevice.requestAccess(for: .video) { granted in
      DispatchQueue.main.async {
        if granted {
          completion("authorized")
        } else {
          completion("denied")
        }
      }
    }
  }
  
  private func openAppSettings() {
    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
      return
    }
    
    if UIApplication.shared.canOpenURL(settingsUrl) {
      UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
        print("Settings opened: \(success)")
      })
    }
  }
}
