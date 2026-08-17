// ios/Runner/AppDelegate.swift
import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register Workmanager for iOS
    WorkmanagerPlugin.registerTask(withIdentifier: "sendReminders")
    WorkmanagerPlugin.registerTask(withIdentifier: "resetPendingIds")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}