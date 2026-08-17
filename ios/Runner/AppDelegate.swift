import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var ambience: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "namethatbaby/backup",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "exclude", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        var url = URL(fileURLWithPath: path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        result(nil)
      } catch {
        result(FlutterError(
          code: "backup_exclusion_failed",
          message: "Could not exclude local session data from backup.",
          details: nil
        ))
      }
    }
    let soundChannel = FlutterMethodChannel(
      name: "namethatbaby/soundscape",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    soundChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "startAmbience" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.startAmbience()
      result(nil)
    }
  }

  private func startAmbience() {
    guard ambience?.isPlaying != true,
          let path = Bundle.main.path(
            forResource: "ambience",
            ofType: "wav",
            inDirectory: "flutter_assets/assets/audio"
          ) else { return }
    ambience = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
    ambience?.numberOfLoops = -1
    ambience?.volume = 0.12
    ambience?.prepareToPlay()
    ambience?.play()
  }
}
