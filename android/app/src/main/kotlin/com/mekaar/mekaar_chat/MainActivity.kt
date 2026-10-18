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
import android.util.Log
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
        const val TAG = "MainActivity"
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

            // Dapatkan URI file dari FileProvider dengan fallback otomatis ke cacheDir
            val apkUri = try {
                FileProvider.getUriForFile(
                    applicationContext,
                    "${applicationContext.packageName}.fileprovider",
                    file
                )
            } catch (e: Exception) {
                Log.w(TAG, "FileProvider getUriForFile fallback ke cacheDir: ${e.message}")
                val cacheDirUpdates = File(applicationContext.cacheDir, "updates")
                if (!cacheDirUpdates.exists()) cacheDirUpdates.mkdirs()
                val targetFile = File(cacheDirUpdates, file.name)
                file.copyTo(targetFile, overwrite = true)
                FileProvider.getUriForFile(
                    applicationContext,
                    "${applicationContext.packageName}.fileprovider",
                    targetFile
                )
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
            }

            // Berikan grantUriPermission eksplisit ke semua paket yang dapat menangani intent
            val resInfoList = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.queryIntentActivities(
                    intent,
                    PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong())
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            }

            for (resolveInfo in resInfoList) {
                try {
                    grantUriPermission(
                        resolveInfo.activityInfo.packageName,
                        apkUri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                } catch (_: Exception) {}
            }

            // Berikan izin eksplisit ke installer paket bawaan sistem Android (Google & AOSP)
            val systemInstallers = listOf(
                "com.google.android.packageinstaller",
                "com.android.packageinstaller"
            )
            for (pkg in systemInstallers) {
                try {
                    grantUriPermission(pkg, apkUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } catch (_: Exception) {}
            }

            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Gagal memasang APK dari $filePath", e)
            result.error("INSTALL_ERROR", e.message ?: "Gagal menjalankan installer APK", null)
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
                val resolver = applicationContext.contentResolver

                // Cek apakah berkas dengan nama dan ukuran yang sama sudah ada di MediaStore Downloads
                val projection = arrayOf(MediaStore.Downloads._ID, MediaStore.Downloads.SIZE)
                val selection = "${MediaStore.Downloads.DISPLAY_NAME} = ?"
                val selectionArgs = arrayOf(fileName)
                val cursor = resolver.query(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    null
                )

                var alreadyExists = false
                cursor?.use {
                    if (it.moveToFirst()) {
                        val sizeIndex = it.getColumnIndex(MediaStore.Downloads.SIZE)
                        if (sizeIndex != -1) {
                            val existingSize = it.getLong(sizeIndex)
                            if (existingSize == sourceFile.length()) {
                                alreadyExists = true
                                exportedPath = "Download/$fileName"
                            }
                        }
                    }
                }

                if (!alreadyExists) {
                    val contentValues = ContentValues().apply {
                        put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                        put(MediaStore.Downloads.MIME_TYPE, "application/vnd.android.package-archive")
                        put(MediaStore.Downloads.IS_PENDING, 1)
                    }
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
            }

            // 2. Fallback / Direct copy jika MediaStore tidak menghasilkan path (Android < 10)
            if (exportedPath == null) {
                val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (!downloadsDir.exists()) {
                    downloadsDir.mkdirs()
                }
                val destFile = File(downloadsDir, fileName)
                if (!destFile.exists() || destFile.length() != sourceFile.length()) {
                    sourceFile.copyTo(destFile, overwrite = true)
                }
                exportedPath = destFile.absolutePath
            }

            result.success(exportedPath)
        } catch (e: Exception) {
            Log.e(TAG, "Error exporting APK to public downloads", e)
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
