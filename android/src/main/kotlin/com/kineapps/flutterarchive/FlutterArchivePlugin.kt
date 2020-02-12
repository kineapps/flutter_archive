package com.kineapps.flutterarchive

import android.util.Log

import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.util.zip.ZipOutputStream
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * FlutterArchivePlugin
 */
class FlutterArchivePlugin : MethodCallHandler {
    companion object {
        private const val LOG_TAG = "FlutterArchivePlugin"
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "flutter_archive")
            channel.setMethodCallHandler(FlutterArchivePlugin())
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when {
            call.method == "zip" -> {
                try {
                    val sourceDir = call.argument<String>("sourceDir")
                    val zipFile = call.argument<String>("zipFile")
                    val recurseSubDirs = call.argument<Boolean>("recurseSubDirs")

                    // https://proandroiddev.com/android-coroutine-recipes-33467a4302e9
                    val uiScope = CoroutineScope(Dispatchers.Main)

                    uiScope.launch {
                        withContext(Dispatchers.IO) {
                            zip(sourceDir, zipFile, recurseSubDirs)
                        }
                        result.success(true)
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                    result.error("zip_error", e.localizedMessage, e)
                }
            }
            call.method == "zipFiles" -> {
                try {
                    val sourceDir = call.argument<String>("sourceDir")
                    val files = call.argument<List<String>>("files")
                    val zipFile = call.argument<String>("zipFile")

                    // https://proandroiddev.com/android-coroutine-recipes-33467a4302e9
                    val uiScope = CoroutineScope(Dispatchers.Main)

                    uiScope.launch {
                        withContext(Dispatchers.IO) {
                            zipFiles(sourceDir, files!!, zipFile)
                        }
                        result.success(true)
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                    result.error("zip_error", e.localizedMessage, e)
                }
            }
            call.method == "unzip" -> {
                try {
                    val zipFile = call.argument<String>("zipFile")
                    val destinationDir = call.argument<String>("destinationDir")

                    val uiScope = CoroutineScope(Dispatchers.Main)

                    uiScope.launch {
                        withContext(Dispatchers.IO) {
                            unzip(zipFile, destinationDir)
                        }
                        result.success(true)
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                    result.error("unzip_error", e.localizedMessage, e)
                }
            }
            else -> result.notImplemented()
        }
    }

    @Throws(IOException::class)
    private fun zip(sourceDirPath: String?, zipFilePath: String?, recurseSubDirs: Boolean?) {
        val rootDirectory = File(sourceDirPath)

        Log.i("zip", "Root directory: $sourceDirPath")
        Log.i("zip", "Zip file path: $zipFilePath")
        Log.i("zip", "Sub directories: $recurseSubDirs")

        ZipOutputStream(BufferedOutputStream(FileOutputStream(zipFilePath))).use { zipOutputStream ->
            addFilesInDirectoryToZip(zipOutputStream, rootDirectory, sourceDirPath!!, recurseSubDirs == true)
        }
    }

    private fun addFilesInDirectoryToZip(zipOutputStream: ZipOutputStream, rootDirectory: File, directoryPath: String, recurseSubDirs: Boolean) {
        val directory = File(directoryPath)

        for (f in directory.listFiles()) {
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
    private fun zipFiles(sourceDirPath: String?, relativeFilePaths: List<String>, zipFilePath: String?) {
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
    private fun unzip(zipFilePath: String?, destinationDirPath: String?) {
        var filename: String
        ZipInputStream(BufferedInputStream(FileInputStream(zipFilePath!!))).use { zis ->
            var destinationDir = File(destinationDirPath)
            Log.d(LOG_TAG, "destinationDir.path: ${destinationDir.path}")
            Log.d(LOG_TAG, "destinationDir.canonicalPath: ${destinationDir.canonicalPath}")
            Log.d(LOG_TAG, "destinationDir.absolutePath: ${destinationDir.absolutePath}")
            while (true) {
                val ze = zis.nextEntry ?: break
                filename = ze.name
                Log.d(LOG_TAG, "zipEntry fileName=$filename")

                val outputFile = File(destinationDirPath, filename)

                // prevent Zip Path Traversal attack
                // https://support.google.com/faqs/answer/9294009
                var outputFileCanonicalPath = outputFile.canonicalPath
                if (!outputFileCanonicalPath.startsWith(destinationDir.canonicalPath)) {
                    Log.d(LOG_TAG, "outputFile path: ${outputFile.path}")
                    Log.d(LOG_TAG, "canonicalPath: $outputFileCanonicalPath")
                    throw SecurityException("Invalid zip file")
                }

                // need to create any missing directories
                if (ze.isDirectory) {
                    Log.d(LOG_TAG, "Creating directory: " + outputFile.path)
                    outputFile.mkdirs()
                    continue
                }

                val parentDir = outputFile.parentFile
                if (!parentDir.exists()) {
                    Log.d(LOG_TAG, "Creating directory: " + parentDir.path)
                    parentDir.mkdirs()
                }

                Log.d(LOG_TAG, "Writing file: " + outputFile.path)
                outputFile.outputStream().use { outputStream -> zis.copyTo(outputStream) }
                zis.closeEntry()
            }
        }
    }
}
