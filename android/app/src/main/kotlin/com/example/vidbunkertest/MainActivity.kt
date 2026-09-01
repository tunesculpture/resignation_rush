package com.example.vidbunkertest

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "vidbunker/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "download") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val url = call.argument<String>("url")
                val fileName = call.argument<String>("fileName") ?: "video.mp4"
                val userAgent = call.argument<String>("userAgent")

                if (url.isNullOrBlank()) {
                    result.error("INVALID_URL", "Download URL is empty.", null)
                    return@setMethodCallHandler
                }

                try {
                    val request = DownloadManager.Request(Uri.parse(url)).apply {
                        setTitle(fileName)
                        setDescription("VidBunker video download")
                        setNotificationVisibility(
                            DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
                        )
                        setDestinationInExternalPublicDir(
                            Environment.DIRECTORY_DOWNLOADS,
                            "VidBunker/$fileName"
                        )
                        setMimeType("video/mp4")
                        setAllowedOverMetered(true)
                        setAllowedOverRoaming(true)
                        if (!userAgent.isNullOrBlank()) {
                            addRequestHeader("User-Agent", userAgent)
                        }
                        addRequestHeader("Accept", "*/*")
                    }

                    val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                    manager.enqueue(request)
                    result.success("Download started. Check Downloads/VidBunker.")
                } catch (e: Exception) {
                    result.error(
                        "DOWNLOAD_FAILED",
                        e.message ?: "Unable to start download.",
                        null
                    )
                }
            }
    }
}
