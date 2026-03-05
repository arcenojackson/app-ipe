package com.ipe.app

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Edge-to-edge explícito (Android 15+ / Play Console). Funciona com FlutterActivity.
        WindowCompat.enableEdgeToEdge(window)
    }
}
