package com.example.vtoroe_me

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val BATTERY_CHANNEL = "vtoroe_me/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestIgnoreBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            val packageName = packageName
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                // Открываем системный диалог для конкретного приложения
                                val intent = Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                                ).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
