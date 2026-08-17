package com.example.namethatbaby

import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ambience: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "namethatbaby/soundscape")
            .setMethodCallHandler { call, result ->
                if (call.method == "startAmbience") {
                    startAmbience()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun startAmbience() {
        if (ambience?.isPlaying == true) return
        val asset = assets.openFd("flutter_assets/assets/audio/ambience.wav")
        ambience = MediaPlayer().apply {
            setDataSource(asset.fileDescriptor, asset.startOffset, asset.length)
            asset.close()
            isLooping = true
            setVolume(0.12f, 0.12f)
            prepare()
            start()
        }
    }

    override fun onDestroy() {
        ambience?.release()
        ambience = null
        super.onDestroy()
    }
}
