// Copyright (c) 2020 KineApps. All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.

#if os(OSX)
import FlutterMacOS
#elseif os(iOS)
import Flutter
#endif

/// https://github.com/weichsel/ZIPFoundation
import ZIPFoundation

enum ZipFileOperation: String {
    case includeItem
    case skipItem
    case cancel
}

public class SwiftFlutterArchivePlugin: NSObject, FlutterPlugin {
    init(_ channel: FlutterMethodChannel) {
        self.channel = channel
    }

    let channel: FlutterMethodChannel

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(OSX)
        let channel = FlutterMethodChannel(name: "flutter_archive", binaryMessenger: registrar.messenger)
        #elseif os(iOS)
        let channel = FlutterMethodChannel(name: "flutter_archive", binaryMessenger: registrar.messenger())
        #endif

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
            let includeBaseDirectory = args["includeBaseDirectory"] as? Bool == true
            let recurseSubDirs = args["recurseSubDirs"] as? Bool == true
            let reportProgress = args["reportProgress"] as? Bool == true
            let jobId = args["jobId"] as? Int

            log("sourceDir: " + sourceDir)
            log("zipFile: " + zipFile)
            log("includeBaseDirectory: " + includeBaseDirectory.description)
            log("recurseSubDirs: " + recurseSubDirs.description)
            log("reportProgress: " + reportProgress.description)
            log("jobId: " + (jobId?.description ?? ""))

            DispatchQueue.global(qos: .userInitiated).async {
                let fileManager = FileManager()
                let sourceURL = URL(fileURLWithPath: sourceDir)
                let destinationURL = URL(fileURLWithPath: zipFile)
                do {
                    if reportProgress || !recurseSubDirs {
                        try self.zipDirectory(at: sourceURL,
                                              to: destinationURL,
                                              recurseSubDirs: recurseSubDirs,
                                              includeBaseDirectory: includeBaseDirectory,
                                              reportProgress: reportProgress,
                                              jobId: jobId)
                    } else {
                        try fileManager.zipItem(at: sourceURL,
                                                to: destinationURL,
                                                shouldKeepParent: includeBaseDirectory,
                                                compressionMethod: .deflate)
                    }
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
            let includeBaseDirectory = args["includeBaseDirectory"] as? Bool == true

            log("files: " + files.joined(separator: ","))
            log("zipFile: " + zipFile)
            log("includeBaseDirectory: " + includeBaseDirectory.description)

            DispatchQueue.global(qos: .userInitiated).async {
                var sourceURL = URL(fileURLWithPath: sourceDir)
                if includeBaseDirectory {
                    sourceURL = sourceURL.deletingLastPathComponent()
                }
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
            let jobId = args["jobId"] as? Int
            let zipFileCharset = args["zipFileCharset"] as? String
            log("zipFile: " + zipFile)
            log("destinationDir: " + destinationDir)
            log("zipFileCharset: " + (zipFileCharset ?? ""))

            DispatchQueue.global(qos: .userInitiated).async {
                let fileManager = FileManager()
                let sourceURL = URL(fileURLWithPath: zipFile)
                let destinationURL = URL(fileURLWithPath: destinationDir)
                let preferredEncoding = self.charSet2Encoding(zipFileCharset: zipFileCharset) as? String.Encoding;
                do {
                    if reportProgress == true {
                        try self.unzipItemAndReportProgress(at: sourceURL, to: destinationURL, jobId: jobId!, preferredEncoding: preferredEncoding)
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

    private func charSet2Encoding(zipFileCharset: String?) ->String.Encoding? {
        switch (zipFileCharset) {
            case ("ISO_8859_1"): return String.Encoding.isoLatin1
            case ("US_ASCII"): return String.Encoding.ascii
            case ("UTF_16"): return String.Encoding.utf16
            case ("UTF_16BE"): return String.Encoding.utf16BigEndian
            case ("UTF_16LE"): return String.Encoding.utf16LittleEndian
            case ("UTF_8"): return String.Encoding.utf8
            case ("CP437"): return nil
            default: return nil
        }
    }

    private func zipDirectory(at sourceURL: URL,
                              to zipFileURL: URL,
                              recurseSubDirs: Bool,
                              includeBaseDirectory: Bool,
                              reportProgress: Bool,
                              jobId: Int?) throws
    {
        var files = [URL]()
        if let enumerator = FileManager.default.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: recurseSubDirs ?
                [.skipsHiddenFiles, .skipsPackageDescendants] :
                [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])
        {
            for case let fileURL as URL in enumerator {
                let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if fileAttributes.isRegularFile! {
                    let url = fileURL.standardizedFileURL
                    log("Found file: " + url.path)
                    files.append(url)
                }
            }
        }

        // create zip archive
        let archive = Archive(url: zipFileURL, accessMode: .create)

        let totalEntriesCount = Double(files.count)
        var currentEntryIndex: Double = 0

        let dispatchGroup = DispatchGroup()

        let baseDirUrl = URL(fileURLWithPath: includeBaseDirectory ?
            sourceURL.deletingLastPathComponent().path : sourceURL.path).standardizedFileURL
        log("baseDirUrl: " + baseDirUrl.path)
        for item in files {
            if reportProgress {
                log("File: " + item.path)
                currentEntryIndex += 1
                let progress: Double = currentEntryIndex / totalEntriesCount * 100.0

                let entryDic: [String: Any] = [
                    "name": item.path,
                    "isDirectory": item.isDirectory,
                    "jobId": jobId!,
                    "progress": progress,
                ]

                var extractOperation: ZipFileOperation?
                dispatchGroup.enter()
                DispatchQueue.main.async {
                    self.channel.invokeMethod("progress", arguments: entryDic) {
                        (result: Any?) -> Void in
                        if let error = result as? FlutterError {
                            self.log("failed: \(error)")
                            extractOperation = ZipFileOperation.includeItem
                        } else if FlutterMethodNotImplemented.isEqual(result) {
                            self.log("not implemented")
                            extractOperation = ZipFileOperation.includeItem
                        } else {
                            extractOperation = ZipFileOperation(rawValue: result as! String)
                            self.log("result: \(String(describing: extractOperation))")
                        }
                        dispatchGroup.leave()
                    }
                }


                log("Waiting...")
                dispatchGroup.wait()
                log("..waiting")
                if extractOperation == ZipFileOperation.skipItem {
                    log("skip")
                    continue
                } else if extractOperation == ZipFileOperation.cancel {
                    log("cancel")
                    break
                }
            }

            let relativePath = item.path.replacingFirstOccurrence(of: baseDirUrl.path + "/", with: "")
            log("Adding: " + relativePath)
            try archive?.addEntry(with: relativePath, relativeTo: baseDirUrl, compressionMethod: .deflate)
        }
    }

    /// Unzips the contents at the specified source URL to the destination URL.
    ///
    /// - Parameters:
    ///   - sourceURL: The file URL pointing to an existing ZIP file.
    ///   - destinationURL: The file URL that identifies the destination directory of the unzip operation.
    ///   - jobId: Job id
    ///   - skipCRC32: Optional flag to skip calculation of the CRC32 checksum to improve performance.
    ///   - preferredEncoding: Encoding for entry paths. Overrides the encoding specified in the archive.
    /// - Throws: Throws an error if the source item does not exist or the destination URL is not writable.
    private func unzipItemAndReportProgress(at sourceURL: URL, to destinationURL: URL, jobId: Int, skipCRC32: Bool = false,
                                            preferredEncoding: String.Encoding? = nil) throws
    {
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

            var entryDic = entryToDictionary(entry: entry, preferredEncoding: preferredEncoding)
            currentEntryIndex += 1
            let progress: Double = currentEntryIndex / totalEntriesCount * 100.0
            entryDic["jobId"] = jobId
            entryDic["progress"] = progress
            var extractOperation: ZipFileOperation?
            dispatchGroup.enter()
            DispatchQueue.main.async {
                self.channel.invokeMethod("progress", arguments: entryDic) {
                    (result: Any?) -> Void in
                    if let error = result as? FlutterError {
                        self.log("failed: \(error)")
                        extractOperation = ZipFileOperation.includeItem
                    } else if FlutterMethodNotImplemented.isEqual(result) {
                        self.log("not implemented")
                        extractOperation = ZipFileOperation.includeItem
                    } else {
                        extractOperation = ZipFileOperation(rawValue: result as! String)
                        self.log("result: \(String(describing: extractOperation))")
                    }
                    dispatchGroup.leave()
                }
            }

            log("Waiting...")
            dispatchGroup.wait()
            log("..waiting")
            if extractOperation == ZipFileOperation.skipItem {
                log("skip")
                continue
            } else if extractOperation == ZipFileOperation.cancel {
                log("cancel")
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

    private func entryToDictionary(entry: Entry, preferredEncoding: String.Encoding? = nil) -> [String: Any] {
        let date = entry.fileAttributes[FileAttributeKey.modificationDate] as? Date
        let millis = Int(date?.timeIntervalSince1970 ?? 0) * 1000
        let dic: [String: Any] = [
            "name": preferredEncoding == nil ? entry.path : entry.path(using: preferredEncoding!),
            "isDirectory": entry.type == Entry.EntryType.directory,
            "modificationDate": millis,
            "uncompressedSize": entry.uncompressedSize,
            "compressedSize": entry.compressedSize,
            "crc": entry.checksum,
            "compressionMethod": entry.compressedSize != entry.uncompressedSize ? "deflated" : "none",
        ]
        return dic
    }
}

extension URL {
    var isDirectory: Bool {
        return (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}

extension String {
    func replacingFirstOccurrence(of target: String, with replacement: String) -> String {
        guard let range = self.range(of: target) else { return self }
        return replacingCharacters(in: range, with: replacement)
    }
}
