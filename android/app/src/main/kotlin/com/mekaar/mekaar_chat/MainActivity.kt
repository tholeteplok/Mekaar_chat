package com.mekaar.mekaar_chat

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val SECURITY_CHANNEL = "com.mekaar.mekaar_chat/security"
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
}
