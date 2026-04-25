// android/app/src/main/kotlin/com/example/smart_medicine_dispenser/AlarmActivity.kt
package com.example.smart_medicine_dispenser

import android.app.KeyguardManager
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AlarmActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "alarm_data_channel"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show over lock screen and turn screen on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Read data passed via intent extras (set by the notification's full-screen intent)
        val alarmId = intent.getIntExtra("alarmId", 0)
        val medicationName = intent.getStringExtra("medicationName") ?: "Medicine"
        val doseInfo = intent.getStringExtra("doseInfo") ?: ""

        // Send data to Flutter so AlarmScreen can display it
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).invokeMethod(
            "alarmTriggered",
            mapOf(
                "alarmId" to alarmId,
                "medicationName" to medicationName,
                "doseInfo" to doseInfo
            )
        )
    }

    override fun getCachedEngineId(): String? = null // Always create a fresh engine

    // When the activity finishes, cancel the ongoing notification
    override fun onDestroy() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(intent.getIntExtra("alarmId", 0))
        super.onDestroy()
    }
}