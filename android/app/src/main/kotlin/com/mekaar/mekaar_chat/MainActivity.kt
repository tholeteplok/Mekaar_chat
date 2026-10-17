package com.mekaar.mekaar_chat

import android.app.DownloadManager
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private companion object {
        const val SECURITY_CHANNEL = "com.mekaar.mekaar_chat/security"
        const val INSTALLER_CHANNEL = "com.mekaar.mekaar_chat/installer"
        const val CAPTURE_CHANNEL = "com.mekaar.mekaar_chat/screen_capture"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CAPTURE_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                events?.success(false)
            }

            override fun onCancel(arguments: Any?) {}
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURITY_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecureFlag" -> updateSecureFlag(enabled = true, result)
                "disableSecureFlag" -> updateSecureFlag(enabled = false, result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INSTALLER_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        installApk(filePath, result)
                    } else {
                        result.error("INVALID_PATH", "File path cannot be null", null)
                    }
                }
                "canRequestPackageInstalls" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val settingsIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(settingsIntent)
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                "exportToPublicDownloads" -> {
                    val filePath = call.argument<String>("filePath")
                    val fileName = call.argument<String>("fileName") ?: "Mekaar-update.apk"
                    if (filePath != null) {
                        exportToPublicDownloads(filePath, fileName, result)
                    } else {
                        result.error("INVALID_PATH", "File path cannot be null", null)
                    }
                }
                "openDownloadsFolder" -> {
                    openDownloadsFolder(result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun updateSecureFlag(enabled: Boolean, result: MethodChannel.Result) {
        runOnUiThread {
            if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            result.success(null)
        }
    }

    private fun installApk(filePath: String, result: MethodChannel.Result) {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                return
            }

            val apkUri = FileProvider.getUriForFile(
                applicationContext,
                "${applicationContext.packageName}.fileprovider",
                file
            )

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            val resInfoList = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            for (resolveInfo in resInfoList) {
                grantUriPermission(resolveInfo.activityInfo.packageName, apkUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("INSTALL_ERROR", e.message, null)
        }
    }

    private fun exportToPublicDownloads(filePath: String, fileName: String, result: MethodChannel.Result) {
        try {
            val sourceFile = File(filePath)
            if (!sourceFile.exists()) {
                result.error("FILE_NOT_FOUND", "Source file not found at $filePath", null)
                return
            }

            var exportedPath: String? = null

            // 1. Simpan via MediaStore (Android 10 - 15+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val contentValues = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, "application/vnd.android.package-archive")
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val resolver = applicationContext.contentResolver
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                if (uri != null) {
                    resolver.openOutputStream(uri)?.use { out ->
                        FileInputStream(sourceFile).use { input ->
                            input.copyTo(out)
                        }
                    }
                    contentValues.clear()
                    contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
                    resolver.update(uri, contentValues, null, null)
                    exportedPath = "Download/$fileName"
                }
            }

            // 2. Fallback / Direct copy jika MediaStore tidak menghasilkan path
            if (exportedPath == null) {
                val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (!downloadsDir.exists()) {
                    downloadsDir.mkdirs()
                }
                val destFile = File(downloadsDir, fileName)
                sourceFile.copyTo(destFile, overwrite = true)
                exportedPath = destFile.absolutePath
            }

            result.success(exportedPath)
        } catch (e: Exception) {
            result.error("EXPORT_ERROR", e.message, null)
        }
    }

    private fun openDownloadsFolder(result: MethodChannel.Result) {
        try {
            val intent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                result.success(true)
            } else {
                val fallbackIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "*/*"
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(fallbackIntent)
                result.success(true)
            }
        } catch (_: Exception) {
            result.success(false)
        }
    }
}
