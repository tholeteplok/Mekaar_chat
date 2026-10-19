package com.mekaar.mekaar_chat

import android.app.Activity
import android.app.DownloadManager
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import android.webkit.MimeTypeMap
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
        const val WAKELOCK_CHANNEL = "com.mekaar.mekaar_chat/wakelock"
        const val RINGTONE_CHANNEL = "com.mekaar.mekaar_chat/ringtone_picker"
        const val REQUEST_CODE_RINGTONE_PICKER = 2001
    }

    private var pendingRingtoneResult: MethodChannel.Result? = null

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
            WAKELOCK_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> updateWakelock(enabled = true, result)
                "disable" -> updateWakelock(enabled = false, result)
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
                "verifyApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        verifyApk(filePath, result)
                    } else {
                        result.error("INVALID_PATH", "File path cannot be null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RINGTONE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickRingtone" -> {
                    if (pendingRingtoneResult != null) {
                        result.error("ALREADY_ACTIVE", "Pemilihan ringtone sedang berlangsung", null)
                        return@setMethodCallHandler
                    }
                    pendingRingtoneResult = result

                    val typeArg = call.argument<String>("type")
                    val ringtoneType = when (typeArg) {
                        "ringtone" -> RingtoneManager.TYPE_RINGTONE
                        "alarm" -> RingtoneManager.TYPE_ALARM
                        else -> RingtoneManager.TYPE_NOTIFICATION
                    }
                    val pickerTitle = call.argument<String>("title") ?: "Pilih Nada Suara"
                    val currentUri = call.argument<String>("currentUri")

                    val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, ringtoneType)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, pickerTitle)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                        if (!currentUri.isNullOrEmpty()) {
                            try {
                                putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(currentUri))
                            } catch (_: Exception) {}
                        }
                    }

                    try {
                        startActivityForResult(intent, REQUEST_CODE_RINGTONE_PICKER)
                    } catch (e: Exception) {
                        Log.e(TAG, "Gagal membuka pemilih ringtone", e)
                        pendingRingtoneResult?.error("PICKER_ERROR", e.message, null)
                        pendingRingtoneResult = null
                    }
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

    private fun updateWakelock(enabled: Boolean, result: MethodChannel.Result) {
        runOnUiThread {
            if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
            result.success(true)
        }
    }

    private fun verifyApk(filePath: String, result: MethodChannel.Result) {
        try {
            val file = File(filePath)
            if (!file.exists() || file.length() < 1024 * 1024) {
                result.success(false)
                return
            }
            val pkgInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageArchiveInfo(filePath, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageArchiveInfo(filePath, 0)
            }
            result.success(pkgInfo != null)
        } catch (e: Exception) {
            Log.w(TAG, "Gagal memverifikasi APK di $filePath", e)
            result.success(false)
        }
    }

    private fun installApk(filePath: String, result: MethodChannel.Result) {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                return
            }

            // Validasi integritas APK sebelum memicu installer sistem
            val pkgInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageArchiveInfo(filePath, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageArchiveInfo(filePath, 0)
            }
            if (pkgInfo == null) {
                Log.e(TAG, "Berkas APK korup atau tidak dapat diparsing oleh Android: $filePath")
                result.error("PARSE_ERROR", "Berkas APK korup atau tidak lengkap (gagal diparsing Android)", null)
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_RINGTONE_PICKER) {
            val result = pendingRingtoneResult
            pendingRingtoneResult = null

            if (resultCode == Activity.RESULT_OK && data != null) {
                val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                }

                if (uri != null) {
                    try {
                        val ringtone = RingtoneManager.getRingtone(applicationContext, uri)
                        val title = ringtone?.getTitle(applicationContext) ?: "Ringtone Perangkat"
                        val localPath = copyRingtoneToInternalStorage(uri, title)
                        result?.success(mapOf(
                            "path" to localPath,
                            "title" to title,
                            "uri" to uri.toString()
                        ))
                    } catch (e: Exception) {
                        Log.e(TAG, "Gagal menyalin ringtone ke penyimpanan internal: ${e.message}", e)
                        result?.success(mapOf(
                            "path" to uri.toString(),
                            "title" to "Ringtone Perangkat",
                            "uri" to uri.toString()
                        ))
                    }
                } else {
                    result?.success(null)
                }
            } else {
                result?.success(null)
            }
        }
    }

    private fun copyRingtoneToInternalStorage(uri: Uri, title: String): String {
        val sanitizedTitle = title.replace(Regex("[^a-zA-Z0-9._-]"), "_")
        val soundsDir = File(applicationContext.filesDir, "custom_sounds").apply {
            if (!exists()) mkdirs()
        }

        val mimeType = applicationContext.contentResolver.getType(uri)
        val extFromMime = if (mimeType != null) {
            MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
        } else null

        val ext = when {
            !extFromMime.isNullOrEmpty() -> extFromMime
            mimeType?.contains("ogg") == true -> "ogg"
            mimeType?.contains("mp3") == true -> "mp3"
            mimeType?.contains("wav") == true -> "wav"
            mimeType?.contains("flac") == true -> "flac"
            mimeType?.contains("aac") == true -> "aac"
            else -> "m4a"
        }

        val targetFile = File(soundsDir, "${sanitizedTitle}_${System.currentTimeMillis()}.$ext")
        applicationContext.contentResolver.openInputStream(uri)?.use { input ->
            targetFile.outputStream().use { output ->
                input.copyTo(output)
            }
        } ?: throw IllegalStateException("Tidak dapat membaca stream audio dari URI: $uri")

        return targetFile.absolutePath
    }
}
