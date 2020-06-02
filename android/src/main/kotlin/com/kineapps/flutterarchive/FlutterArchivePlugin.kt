// Copyright (c) 2020 KineApps. All rights reserved.
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
import io.flutter.plugin.common.PluginRegistry.Registrar
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.util.zip.ZipEntry
import java.util.zip.ZipEntry.DEFLATED
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

enum class ExtractOperation { extract, skip, cancel }

/**
 * FlutterArchivePlugin
 */
class FlutterArchivePlugin : FlutterPlugin, MethodCallHandler {
    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var methodChannel: MethodChannel? = null

    companion object {
        private const val LOG_TAG = "FlutterArchivePlugin"

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            Log.d(LOG_TAG, "registerWith")
            val plugin = FlutterArchivePlugin()
            plugin.doOnAttachedToEngine(registrar.messenger())
        }
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
                        val recurseSubDirs = call.argument<Boolean>("recurseSubDirs")

                        withContext(Dispatchers.IO) {
                            zip(sourceDir!!, zipFile!!, recurseSubDirs)
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

                        withContext(Dispatchers.IO) {
                            zipFiles(sourceDir!!, files!!, zipFile!!)
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

                        Log.d(LOG_TAG, "onMethodCall / unzip...")
                        withContext(Dispatchers.IO) {
                            unzip(zipFile!!, destinationDir!!, reportProgress == true)
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
    private fun zip(sourceDirPath: String, zipFilePath: String, recurseSubDirs: Boolean?) {
        val rootDirectory = File(sourceDirPath)

        Log.i("zip", "Root directory: $sourceDirPath")
        Log.i("zip", "Zip file path: $zipFilePath")
        Log.i("zip", "Sub directories: $recurseSubDirs")

        ZipOutputStream(BufferedOutputStream(FileOutputStream(zipFilePath))).use { zipOutputStream ->
            addFilesInDirectoryToZip(zipOutputStream, rootDirectory, sourceDirPath, recurseSubDirs == true)
        }
    }

    private fun addFilesInDirectoryToZip(zipOutputStream: ZipOutputStream, rootDirectory: File, directoryPath: String, recurseSubDirs: Boolean) {
        val directory = File(directoryPath)

        val files = directory.listFiles() ?: arrayOf<File>()
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
                zipOutputStream.putNextEntry(entry)

                // zip files and subdirectories in this directory
                addFilesInDirectoryToZip(zipOutputStream, rootDirectory, path, true)
            } else {
                Log.i("zip", "Adding file: $relativePath")
                FileInputStream(f).use { fileInputStream ->
                    val entry = ZipEntry(relativePath)
                    entry.time = f.lastModified()
                    entry.size = f.length()
                    zipOutputStream.putNextEntry(entry)
                    fileInputStream.copyTo(zipOutputStream)
                }
            }
        }
    }

    @Throws(IOException::class)
    private fun zipFiles(sourceDirPath: String, relativeFilePaths: List<String>, zipFilePath: String) {
        val rootDirectory = File(sourceDirPath)

        Log.i("zip", "Root directory: $sourceDirPath")
        Log.i("zip", "Files: ${relativeFilePaths.joinToString(",")}")
        Log.i("zip", "Zip file: $zipFilePath")

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
    private suspend fun unzip(zipFilePath: String, destinationDirPath: String, reportProgress: Boolean) {
        val destinationDir = File(destinationDirPath)

        Log.d(LOG_TAG, "destinationDir.path: ${destinationDir.path}")
        Log.d(LOG_TAG, "destinationDir.canonicalPath: ${destinationDir.canonicalPath}")
        Log.d(LOG_TAG, "destinationDir.absolutePath: ${destinationDir.absolutePath}")

        val uiScope = CoroutineScope(Dispatchers.Main)

        ZipFile(zipFilePath).use { zipFile ->
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

                    val map = zipEntryToMap(ze).toMutableMap()
                    map["progress"] = progress

                    val deferred = CompletableDeferred<ExtractOperation>()

                    uiScope.launch {
                        methodChannel?.invokeMethod("progress", map, object : MethodChannel.Result {

                            override fun success(result: Any?) {
                                Log.i(LOG_TAG, "invokeMethod - success: $result")
                                when (result) {
                                    "cancel" -> {
                                        deferred.complete(ExtractOperation.cancel)
                                    }
                                    "skip" -> {
                                        deferred.complete(ExtractOperation.skip)
                                    }
                                    else -> {
                                        deferred.complete(ExtractOperation.extract)
                                    }
                                }
                            }

                            override fun error(code: String?, msg: String?, details: Any?) {
                                Log.e(LOG_TAG, "invokeMethod - error: $msg")
                                // ignore error and extract normally
                                deferred.complete(ExtractOperation.extract)
                            }

                            override fun notImplemented() {
                                Log.e(LOG_TAG, "invokeMethod - notImplemented")
                                // ignore error and extract normally
                                deferred.complete(ExtractOperation.extract)
                            }
                        })
                    }
                    Log.e(LOG_TAG, "Waiting extractOperation...")
                    val extractOperation = deferred.await()
                    Log.e(LOG_TAG, "...extractOperation=$extractOperation")
                    if (extractOperation == ExtractOperation.skip) {
                        continue
                    } else if (extractOperation == ExtractOperation.cancel) {
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
                    zipFile.getInputStream(ze).use { zis ->
                        outputFile.outputStream().use { outputStream -> zis.copyTo(outputStream) }
                    }
                }
            }
        }
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
}
