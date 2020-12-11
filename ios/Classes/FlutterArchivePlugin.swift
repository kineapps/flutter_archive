import Flutter

public class FlutterArchivePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    SwiftFlutterArchivePlugin.register(with: registrar);
  }
}
