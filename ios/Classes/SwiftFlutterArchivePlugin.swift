// Copyright (c) 2020 KineApps. All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.

import Flutter
import UIKit
/// https://github.com/weichsel/ZIPFoundation
import ZIPFoundation

public class SwiftFlutterArchivePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_archive", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterArchivePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        log("call:" + call.method)

        switch call.method {
            case "zipDirectory":
                guard let args = call.arguments as? [String: Any] else {
                    result(FlutterError(code: "INVALID_ARGUMENTS",
                                        message: "Invalid arguments",
                                        details: nil))
                    return
                }
                guard let sourceDir = args["sourceDir"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS",
                                        message: "Argument 'sourceDir' is missing",
                                        details: nil))
                    return
                }
                guard let zipFile = args["zipFile"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS",
                                        message: "Argument 'zipFile' is missing",
                                        details: nil))
                    return
                }

                log("sourceDir: " + sourceDir)
                log("zipFile: " + zipFile)

                DispatchQueue.global(qos: .userInitiated).async {
                    let fileManager = FileManager()
                    let sourceURL = URL(fileURLWithPath: sourceDir)
                    let destinationURL = URL(fileURLWithPath: zipFile)
                    do {
                        try fileManager.zipItem(at: sourceURL,
                                                to: destinationURL,
                                                shouldKeepParent: false,
                                                compressionMethod: .deflate)
                        DispatchQueue.main.async {
                            self.log("Created zip at: " + destinationURL.path)
                            result(true)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.log("Creation of ZIP archive failed with error:\(error)")
                            result(FlutterError(code: "ZIP_ERROR",
                                                message: error.localizedDescription,
                                                details: nil))
                        }
                    }
                }

            case "zipFiles":
                guard let args = call.arguments as? [String: Any] else {
                    result(FlutterError(code: "INVALID_ARGUMENTS",
                                        message: "Invalid arguments",
                                        details: nil))
                    return
                }
                guard let sourceDir = args["sourceDir"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS",
                                        message: "Argument 'sourceDir' is missing",
                                        details: nil))
                    return
                }
                guard let files = args["files"] as? [String] else {
                    result(FlutterError(code: "INVALID_ARGUMENTS",
                                        message: "Argument 'files' is missing",
                                        details: nil))
                    return
                }
                guard let zipFile = args["zipFile"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS",
                                        message: "Argument 'zipFile' is missing",
                                        details: nil))
                    return
                }

                log("files: " + files.joined(separator: ","))
                log("zipFile: " + zipFile)

                DispatchQueue.global(qos: .userInitiated).async {
                    let sourceURL = URL(fileURLWithPath: sourceDir)
                    let destinationURL = URL(fileURLWithPath: zipFile)
                    do {
                        // create zip archive
                        let archive = Archive(url: destinationURL, accessMode: .create)

                        for item in files {
                            self.log("Adding: " + item)
                            try archive?.addEntry(with: item, relativeTo: sourceURL, compressionMethod: .deflate)
                        }
                        DispatchQueue.main.async {
                            self.log("Created zip at: " + archive.debugDescription)
                            result(true)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.log("Creation of ZIP archive failed with error:\(error)")
                            result(FlutterError(code: "ZIP_ERROR",
                                                message: error.localizedDescription,
                                                details: nil))
                        }
                    }
                }

            case "unzip":
                guard let args = call.arguments as? [String: Any] else {
                    result(FlutterError(code: "INVALID_ARGUMENTS",
                                        message: "Invalid arguments",
                                        details: nil))
                    return
                }
                guard let zipFile = args["zipFile"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS",
                                        message: "Argument 'zipFile' is missing",
                                        details: nil))
                    return
                }
                guard let destinationDir = args["destinationDir"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS",
                                        message: "Argument 'destinationDir' is missing",
                                        details: nil))
                    return
                }

                log("zipFile: " + zipFile)
                log("destinationDir: " + destinationDir)
                DispatchQueue.global(qos: .userInitiated).async {
                    let fileManager = FileManager()
                    let sourceURL = URL(fileURLWithPath: zipFile)
                    let destinationURL = URL(fileURLWithPath: destinationDir)
                    do {
                        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
                        try fileManager.unzipItem(at: sourceURL, to: destinationURL)
                        DispatchQueue.main.async {
                            self.log("Extracted zip to: " + destinationURL.path)
                            result(true)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.log("Extraction of ZIP archive failed with error:\(error)")
                            result(FlutterError(code: "UNZIP_ERROR",
                                                message: error.localizedDescription,
                                                details: nil))
                        }
                    }
                }

            default:
                log("not implemented")
                result(FlutterMethodNotImplemented)
        }
    }

    /// https://github.com/flutter/flutter/issues/13204
    private func log(_ message: String) {
        NSLog("\n" + message)
    }
}
