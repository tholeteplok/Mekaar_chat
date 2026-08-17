package com.mekaar.mekaar_chat

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private companion object {
        const val SECURITY_CHANNEL = "com.mekaar.mekaar_chat/security"
        const val INSTALLER_CHANNEL = "com.mekaar.mekaar_chat/installer"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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

            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("INSTALL_ERROR", e.message, null)
        }
    }
}
