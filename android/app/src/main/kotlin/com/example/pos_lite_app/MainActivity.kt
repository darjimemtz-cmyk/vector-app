package com.example.pos_lite_app

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.pos_lite_app/zebra"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "imprimirZebra") {
                val zpl = call.argument<String>("zpl") ?: ""
                try {
                    val intent = Intent().apply {
                        component = ComponentName("com.zebra.printconnect", "com.zebra.printconnect.print.PassthroughService")
                        putExtra("com.zebra.printconnect.PrintService.PASSTHROUGH_DATA", zpl.toByteArray(Charsets.UTF_8))
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}