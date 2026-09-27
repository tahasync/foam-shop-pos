package com.asif.foamshop

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    /// Saves a PDF into the device's public Downloads folder via MediaStore.
    ///
    /// The Dart side used to write the file with `dart:io`'s `File` straight
    /// into `/storage/emulated/0/Download`. Since Android 10 that path is
    /// covered by scoped storage: the write throws (or silently lands nowhere),
    /// so "Save PDF" reported success while no file ever appeared in the phone's
    /// storage. `WRITE_EXTERNAL_STORAGE` is also capped at `maxSdkVersion=28`,
    /// so there is no permission to request on a modern device.
    ///
    /// MediaStore is the sanctioned route: it needs no runtime permission from
    /// Android 10 onward and the file shows up in Files, Downloads and any
    /// gallery app, exactly where a shopkeeper expects to find a receipt.
    ///
    /// Below API 29 there is no scoped storage, so the old direct write is still
    /// correct and is kept as the fallback.
    private val channelName = "com.asif.foamshop/receipts"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "savePdf" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name")
                        if (bytes == null || name.isNullOrBlank()) {
                            result.error("bad_args", "bytes and name are required", null)
                        } else {
                            try {
                                result.success(savePdf(bytes, name))
                            } catch (e: Exception) {
                                result.error("save_failed", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun savePdf(bytes: ByteArray, name: String): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveViaMediaStore(bytes, name)
        } else {
            saveLegacy(bytes, name)
        }
    }

    private fun saveViaMediaStore(bytes: ByteArray, name: String): String {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
            // IS_PENDING hides the row until the bytes are fully written, so a
            // half-written PDF never appears in the user's Downloads folder.
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("MediaStore rejected the insert")

        try {
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Could not open the output stream")
        } catch (e: Exception) {
            // Never leave an orphaned pending row behind on failure.
            resolver.delete(uri, null, null)
            throw e
        }

        values.clear()
        values.put(MediaStore.Downloads.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return uri.toString()
    }

    @Suppress("DEPRECATION")
    private fun saveLegacy(bytes: ByteArray, name: String): String {
        val dir = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, name)
        FileOutputStream(file).use { it.write(bytes) }
        return file.absolutePath
    }
}
