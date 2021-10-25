// Copyright (c) 2020-2021 KineApps. All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.

package com.kineapps.flutterarchive

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedOutputStream
import java.io.Closeable
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.util.zip.ZipEntry
import java.util.zip.ZipEntry.DEFLATED
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

enum class ZipFileOperation { INCLUDE_ITEM, SKIP_ITEM, CANCEL }

/**
 * FlutterArchivePlugin
 */
class FlutterArchivePlugin : FlutterPlugin, MethodCallHandler {
    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var methodChannel: MethodChannel? = null

    companion object {
        private const val LOG_TAG = "FlutterArchivePlugin"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(LOG_TAG, "onAttachedToEngine - IN")

        if (pluginBinding != null) {
            Log.w(LOG_TAG, "onAttachedToEngine - already attached")
        }

        pluginBinding = binding

        val messenger = pluginBinding?.binaryMessenger
        doOnAttachedToEngine(messenger!!)

        Log.d(LOG_TAG, "onAttachedToEngine - OUT")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(LOG_TAG, "onDetachedFromEngine")
        doOnDetachedFromEngine()
    }

    private fun doOnAttachedToEngine(messenger: BinaryMessenger) {
        Log.d(LOG_TAG, "doOnAttachedToEngine - IN")

        methodChannel = MethodChannel(messenger, "flutter_archive")
        methodChannel?.setMethodCallHandler(this)

        Log.d(LOG_TAG, "doOnAttachedToEngine - OUT")
    }

    private fun doOnDetachedFromEngine() {
        Log.d(LOG_TAG, "doOnDetachedFromEngine - IN")

        if (pluginBinding == null) {
            Log.w(LOG_TAG, "doOnDetachedFromEngine - already detached")
        }
        pluginBinding = null

        methodChannel?.setMethodCallHandler(null)
        methodChannel = null

        Log.d(LOG_TAG, "doOnDetachedFromEngine - OUT")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val uiScope = CoroutineScope(Dispatchers.Main)

        when (call.method) {
            "zipDirectory" -> {
                uiScope.launch {
                    try {
                        val sourceDir = call.argument<String>("sourceDir")
                        val zipFile = call.argument<String>("zipFile")
                        val recurseSubDirs = call.argument<Boolean>("recurseSubDirs") == true
                        val includeBaseDirectory = call.argument<Boolean>("includeBaseDirectory") == true
                        val reportProgress = call.argument<Boolean>("reportProgress")
                        val jobId = call.argument<Int>("jobId")

                        withContext(Dispatchers.IO) {
                            zip(sourceDir!!, zipFile!!, recurseSubDirs, includeBaseDirectory, reportProgress == true, jobId!!)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error("zip_error", e.localizedMessage, e.toString())
                    }
                }
            }
            "zipFiles" -> {
                uiScope.launch {
                    try {
                        val sourceDir = call.argument<String>("sourceDir")
                        val files = call.argument<List<String>>("files")
                        val zipFile = call.argument<String>("zipFile")
                        val includeBaseDirectory = call.argument<Boolean>("includeBaseDirectory") == true

                        withContext(Dispatchers.IO) {
                            zipFiles(sourceDir!!, files!!, zipFile!!, includeBaseDirectory)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error("zip_error", e.localizedMessage, e.toString())
                    }
                }
            }
            "unzip" -> {
                uiScope.launch {
                    try {
                        val zipFile = call.argument<String>("zipFile")
                        val destinationDir = call.argument<String>("destinationDir")
                        val reportProgress = call.argument<Boolean>("reportProgress")
                        val jobId = call.argument<Int>("jobId")

                        Log.d(LOG_TAG, "onMethodCall / unzip...")
                        withContext(Dispatchers.IO) {
                            unzip(zipFile!!, destinationDir!!, reportProgress == true, jobId!!)
                        }
                        Log.d(LOG_TAG, "...onMethodCall / unzip")
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error("unzip_error", e.localizedMessage, e.toString())
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    @Throws(IOException::class)
    private suspend fun zip(sourceDirPath: String, zipFilePath: String, recurseSubDirs: Boolean, includeBaseDirectory: Boolean, reportProgress: Boolean, jobId: Int) {
        Log.i("zip", "sourceDirPath: $sourceDirPath, zipFilePath: $zipFilePath, recurseSubDirs: $recurseSubDirs, includeBaseDirectory: $includeBaseDirectory")

        val rootDirectory = if (includeBaseDirectory) File(sourceDirPath).parentFile else File(sourceDirPath)

        val totalFileCount = if (reportProgress) getFilesCount(rootDirectory, recurseSubDirs) else 0

        withContext(Dispatchers.IO) {
            ZipOutputStream(BufferedOutputStream(FileOutputStream(zipFilePath))).use { zipOutputStream ->
                addFilesInDirectoryToZip(zipOutputStream, rootDirectory, sourceDirPath, recurseSubDirs, reportProgress, jobId, totalFileCount, 0)
            }
        }
    }

    /**
     * Add all files in [rootDirectory] to [zipOutputStream].
     *
     * @return Updated total number of handled files
     */
    private suspend fun addFilesInDirectoryToZip(
            zipOutputStream: ZipOutputStream,
            rootDirectory: File,
            directoryPath: String,
            recurseSubDirs: Boolean,
            reportProgress: Boolean,
            jobId: Int,
            totalFilesCount: Int,
            totalHandledFilesCount: Int): Int {
        val directory = File(directoryPath)

        val files = directory.listFiles() ?: arrayOf<File>()
        var handledFilesCount = totalHandledFilesCount
        for (f in files) {
            val path = directoryPath + File.separator + f.name
            val relativePath = File(path).relativeTo(rootDirectory).path

            if (f.isDirectory) {
                // include subdirectories only if requested
                if (!recurseSubDirs) {
                    continue
                }
                Log.i("zip", "Adding directory: $relativePath")

                // add directory entry
                val entry = ZipEntry(relativePath + File.separator)
                entry.time = f.lastModified()
                entry.size = f.length()

                if (reportProgress) {
                    // report progress
                    val progress: Double =
                            handledFilesCount.toDouble() / totalFilesCount.toDouble() * 100.0

                    Log.d(LOG_TAG, "Waiting reportProgress...")
                    val zipFileOperation = reportProgress(jobId, entry, progress)
                    Log.d(LOG_TAG, "...reportProgress: $zipFileOperation")

                    if (zipFileOperation == ZipFileOperation.SKIP_ITEM) {
                        continue
                    } else if (zipFileOperation == ZipFileOperation.CANCEL) {
                        throw CancellationException("Operation cancelled")
                    }
                }

                withContext(Dispatchers.IO) {
                    zipOutputStream.putNextEntry(entry)
                }

                // zip files and subdirectories in this directory
                handledFilesCount = addFilesInDirectoryToZip(
                        zipOutputStream,
                        rootDirectory,
                        path,
                        true,
                        reportProgress,
                        jobId,
                        totalFilesCount,
                        handledFilesCount)
            } else {
                Log.i("zip", "Adding file: $relativePath")
                ++handledFilesCount
                withContext(Dispatchers.IO) {
                    FileInputStream(f).use { fileInputStream ->
                        val entry = ZipEntry(relativePath)
                        entry.time = f.lastModified()
                        entry.size = f.length()

                        if (reportProgress) {
                            // report progress
                            val progress: Double =
                                    handledFilesCount.toDouble() / totalFilesCount.toDouble() * 100.0

                            Log.d(LOG_TAG, "Waiting reportProgress...")
                            val zipFileOperation = reportProgress(jobId, entry, progress)
                            Log.d(LOG_TAG, "...reportProgress: $zipFileOperation")

                            when (zipFileOperation) {
                                ZipFileOperation.INCLUDE_ITEM -> {
                                    zipOutputStream.putNextEntry(entry)
                                    fileInputStream.copyTo(zipOutputStream)
                                }
                                ZipFileOperation.CANCEL -> {
                                    throw CancellationException("Operation cancelled")
                                }
                                else -> {
                                    // skip this entry
                                }
                            }
                        } else {
                            zipOutputStream.putNextEntry(entry)
                            fileInputStream.copyTo(zipOutputStream)
                        }
                    }
                }
            }
        }
        return handledFilesCount
    }

    @Throws(IOException::class)
    private fun zipFiles(sourceDirPath: String, relativeFilePaths: List<String>, zipFilePath: String, includeBaseDirectory: Boolean) {
        Log.i("zip", "sourceDirPath: $sourceDirPath, zipFilePath: $zipFilePath, includeBaseDirectory: $includeBaseDirectory")
        Log.i("zip", "Files: ${relativeFilePaths.joinToString(",")}")

        val rootDirectory = if (includeBaseDirectory) File(sourceDirPath).parentFile else File(sourceDirPath)

        ZipOutputStream(BufferedOutputStream(FileOutputStream(zipFilePath))).use { zipOutputStream ->
            for (relativeFilePath in relativeFilePaths) {
                val file = rootDirectory.resolve(relativeFilePath)
                val cleanedRelativeFilePath = file.relativeTo(rootDirectory).path
                Log.i("zip", "Adding file: $cleanedRelativeFilePath")
                FileInputStream(file).use { fileInputStream ->
                    val entry = ZipEntry(cleanedRelativeFilePath)
                    entry.time = file.lastModified()
                    entry.size = file.length()
                    zipOutputStream.putNextEntry(entry)
                    fileInputStream.copyTo(zipOutputStream)
                }
            }
        }
    }

    @Throws(IOException::class)
    private suspend fun unzip(zipFilePath: String, destinationDirPath: String, reportProgress: Boolean, jobId: Int) {
        val destinationDir = File(destinationDirPath)

        Log.d(LOG_TAG, "destinationDir.path: ${destinationDir.path}")
        Log.d(LOG_TAG, "destinationDir.canonicalPath: ${destinationDir.canonicalPath}")
        Log.d(LOG_TAG, "destinationDir.absolutePath: ${destinationDir.absolutePath}")

        ZipFileEx(zipFilePath).use { zipFile ->
            val entriesCount = zipFile.size().toDouble()
            var currentEntryIndex = 0.0
            for (ze in zipFile.entries()) {
                val filename = ze.name
                Log.d(LOG_TAG, "zipEntry fileName=$filename, compressedSize=${ze.compressedSize}, size=${ze.size}, crc=${ze.crc}")

                val outputFile = File(destinationDirPath, filename)

                // prevent Zip Path Traversal attack
                // https://support.google.com/faqs/answer/9294009
                val outputFileCanonicalPath = outputFile.canonicalPath
                if (!outputFileCanonicalPath.startsWith(destinationDir.canonicalPath)) {
                    Log.d(LOG_TAG, "outputFile path: ${outputFile.path}")
                    Log.d(LOG_TAG, "canonicalPath: $outputFileCanonicalPath")
                    throw SecurityException("Invalid zip file")
                }

                if (reportProgress) {
                    // report progress
                    val progress: Double = currentEntryIndex++ / (entriesCount - 1) * 100

                    Log.d(LOG_TAG, "Waiting reportProgress...")
                    val zipFileOperation = reportProgress(jobId, ze, progress)
                    Log.d(LOG_TAG, "...reportProgress: $zipFileOperation")

                    if (zipFileOperation == ZipFileOperation.SKIP_ITEM) {
                        continue
                    } else if (zipFileOperation == ZipFileOperation.CANCEL) {
                        break
                    }
                }

                // need to create any missing directories
                if (ze.isDirectory) {
                    Log.d(LOG_TAG, "Creating directory: " + outputFile.path)
                    outputFile.mkdirs()
                } else {
                    val parentDir = outputFile.parentFile
                    if (parentDir != null && !parentDir.exists()) {
                        Log.d(LOG_TAG, "Creating directory: " + parentDir.path)
                        parentDir.mkdirs()
                    }

                    Log.d(LOG_TAG, "Writing entry to file: " + outputFile.path)
                    withContext(Dispatchers.IO) {
                        zipFile.getInputStream(ze).use { zis ->
                            outputFile.outputStream()
                                .use { outputStream -> zis.copyTo(outputStream) }
                        }
                    }
                }
            }
        }
    }

    private suspend fun reportProgress(jobId: Int, zipEntry: ZipEntry, progress: Double): ZipFileOperation {
        val map = zipEntryToMap(zipEntry).toMutableMap()
        map["jobId"] = jobId
        map["progress"] = progress

        val deferred = CompletableDeferred<ZipFileOperation>()

        val uiScope = CoroutineScope(Dispatchers.Main)
        uiScope.launch {
            methodChannel?.invokeMethod("progress", map, object : Result {

                override fun success(result: Any?) {
                    Log.i(LOG_TAG, "invokeMethod - success: $result")
                    when (result) {
                        "cancel" -> {
                            deferred.complete(ZipFileOperation.CANCEL)
                        }
                        "skipItem" -> {
                            deferred.complete(ZipFileOperation.SKIP_ITEM)
                        }
                        else -> {
                            deferred.complete(ZipFileOperation.INCLUDE_ITEM)
                        }
                    }
                }

                override fun error(code: String?, msg: String?, details: Any?) {
                    Log.e(LOG_TAG, "invokeMethod - error: $msg")
                    // ignore error and extract normally
                    deferred.complete(ZipFileOperation.INCLUDE_ITEM)
                }

                override fun notImplemented() {
                    Log.e(LOG_TAG, "invokeMethod - notImplemented")
                    // ignore error and extract normally
                    deferred.complete(ZipFileOperation.INCLUDE_ITEM)
                }
            })
        }
        return deferred.await()
    }

    /**
     * Return number of files under [dir]. Count also files in subdirectories
     * if [recurseSubDirs] is true.
     */
    private fun getFilesCount(dir: File, recurseSubDirs: Boolean): Int {
        val fileAndDirs = dir.listFiles()
        var count = 0
        if (fileAndDirs != null) {
            for (f in fileAndDirs) {
                if (recurseSubDirs && f.isDirectory) {
                    count += getFilesCount(f, recurseSubDirs)
                } else {
                    count++
                }
            }
        }
        return count
    }

    private fun zipEntryToMap(ze: ZipEntry): Map<String, Any> {
        return mapOf(
                "name" to ze.name,
                "isDirectory" to ze.isDirectory,
                "comment" to ze.comment,
                "modificationDate" to ze.time,
                "uncompressedSize" to ze.size,
                "compressedSize" to ze.compressedSize,
                "crc" to ze.crc,
                "compressionMethod" to (if (ze.method == DEFLATED) "deflated" else "none"))
    }

    // This is needed because ZipFile implements Closeable only starting from API 19 and
    // we support >=16
    class ZipFileEx(name: String?) : ZipFile(name), Closeable
}
