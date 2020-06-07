// Copyright (c) 2020 KineApps. All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.

import Flutter
import UIKit
/// https://github.com/weichsel/ZIPFoundation
import ZIPFoundation

enum ExtractOperation: String {
    case extract
    case skip
    case cancel
}

public class SwiftFlutterArchivePlugin: NSObject, FlutterPlugin {
    init(_ channel: FlutterMethodChannel) {
        self.channel = channel
    }

    let channel: FlutterMethodChannel

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_archive", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterArchivePlugin(channel)
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
                                            shouldKeepParent: true,
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
            let reportProgress = args["reportProgress"] as? Bool

            log("zipFile: " + zipFile)
            log("destinationDir: " + destinationDir)
            DispatchQueue.global(qos: .userInitiated).async {
                let fileManager = FileManager()
                let sourceURL = URL(fileURLWithPath: zipFile)
                let destinationURL = URL(fileURLWithPath: destinationDir)
                do {
                    if reportProgress == true {
                        try self.unzipItemAndReportProgress(at: sourceURL, to: destinationURL)
                    } else {
                        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
                        try fileManager.unzipItem(at: sourceURL, to: destinationURL)
                    }

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

    /// Unzips the contents at the specified source URL to the destination URL.
    ///
    /// - Parameters:
    ///   - sourceURL: The file URL pointing to an existing ZIP file.
    ///   - destinationURL: The file URL that identifies the destination directory of the unzip operation.
    ///   - skipCRC32: Optional flag to skip calculation of the CRC32 checksum to improve performance.
    ///   - preferredEncoding: Encoding for entry paths. Overrides the encoding specified in the archive.
    /// - Throws: Throws an error if the source item does not exist or the destination URL is not writable.
    private func unzipItemAndReportProgress(at sourceURL: URL, to destinationURL: URL, skipCRC32: Bool = false,
                                            preferredEncoding: String.Encoding? = nil) throws {
        // based on https://github.com/weichsel/ZIPFoundation/blob/development/Sources/ZIPFoundation/FileManager%2BZIP.swift
        guard itemExists(at: sourceURL) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: sourceURL.path])
        }
        guard let archive = Archive(url: sourceURL, accessMode: .read, preferredEncoding: preferredEncoding) else {
            throw Archive.ArchiveError.unreadableArchive
        }
        // Defer extraction of symlinks until all files & directories have been created.
        // This is necessary because we can't create links to files that haven't been created yet.
        let sortedEntries = archive.sorted { (left, right) -> Bool in
            switch (left.type, right.type) {
            case (.directory, .file): return true
            case (.directory, .symlink): return true
            case (.file, .symlink): return true
            default: return false
            }
        }

        let totalEntriesCount = Double(sortedEntries.count)
        var currentEntryIndex: Double = 0

        let dispatchGroup = DispatchGroup()
        for entry in sortedEntries {
            let path = preferredEncoding == nil ? entry.path : entry.path(using: preferredEncoding!)
            let destinationEntryURL = destinationURL.appendingPathComponent(path)

            var entryDic = entryToDictionary(entry: entry)
            let progress: Double = currentEntryIndex / totalEntriesCount * 100.0
            entryDic["progress"] = progress
            var extractOperation: ExtractOperation?
            dispatchGroup.enter()
            DispatchQueue.main.async {
                self.channel.invokeMethod("progress", arguments: entryDic) {
                    (result: Any?) -> Void in
                    if let error = result as? FlutterError {
                        self.log("failed: \(error)")
                        extractOperation = ExtractOperation.extract
                    } else if FlutterMethodNotImplemented.isEqual(result) {
                        self.log("not implemented")
                        extractOperation = ExtractOperation.extract
                    } else {
                        extractOperation = ExtractOperation(rawValue: result as! String)
                        self.log("result: \(String(describing: extractOperation))")
                    }
                    dispatchGroup.leave()
                }
            }
            
            currentEntryIndex += 1
            
            log("Waiting...")
            dispatchGroup.wait()
            log("..waiting")
            if extractOperation == ExtractOperation.skip {
                continue
            } else if extractOperation == ExtractOperation.cancel {
                break
            }

            guard destinationEntryURL.isContained(in: destinationURL) else {
                throw CocoaError(.fileReadInvalidFileName,
                                 userInfo: [NSFilePathErrorKey: destinationEntryURL.path])
            }
            _ = try archive.extract(entry, to: destinationEntryURL, skipCRC32: skipCRC32)
        }
    }

    // MARK: - Helpers

    // https://github.com/weichsel/ZIPFoundation/blob/development/Sources/ZIPFoundation/FileManager%2BZIP.swift
    private func itemExists(at url: URL) -> Bool {
        // Use `URL.checkResourceIsReachable()` instead of `FileManager.fileExists()` here
        // because we don't want implicit symlink resolution.
        // As per documentation, `FileManager.fileExists()` traverses symlinks and therefore a broken symlink
        // would throw a `.fileReadNoSuchFile` false positive error.
        // For ZIP files it may be intended to archive "broken" symlinks because they might be
        // resolvable again when extracting the archive to a different destination.
        return (try? url.checkResourceIsReachable()) == true
    }

    /// https://github.com/flutter/flutter/issues/13204
    private func log(_ message: String) {
        NSLog("\n" + message)
    }

    private func entryToDictionary(entry: Entry) -> [String: Any] {
        let date = entry.fileAttributes[FileAttributeKey.modificationDate] as? Date
        let millis = Int(date?.timeIntervalSince1970 ?? 0) * 1000
        let dic: [String: Any] = [
            "name": entry.path,
            "isDirectory": entry.type == Entry.EntryType.directory,
            "modificationDate": millis,
            "uncompressedSize": entry.uncompressedSize,
            "compressedSize": entry.compressedSize,
            "crc": entry.checksum,
            "compressionMethod": entry.compressedSize != entry.uncompressedSize ? "deflated" : "none"
        ]
        return dic
    }
}
