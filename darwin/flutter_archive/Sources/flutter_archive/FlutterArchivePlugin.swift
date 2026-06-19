#if os(macOS)
import Cocoa
import FlutterMacOS
#elseif os(iOS)
import Flutter
#endif

public class FlutterArchivePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    SwiftFlutterArchivePlugin.register(with: registrar);
  }
}
