package br.com.mar.projeto_integrado_flutter_app

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    private var pending: Pair<ByteArray, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "br.com.mar/documentos")
            .setMethodCallHandler { call, result ->
                if (call.method != "savePdf") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val id = call.argument<Number>("id")
                if (bytes == null || bytes.isEmpty() || id == null) {
                    result.error("invalid_pdf", "Ficha inválida", null)
                    return@setMethodCallHandler
                }
                if (pending != null) {
                    result.error("busy", "Já há uma ficha aberta para salvar", null)
                    return@setMethodCallHandler
                }
                pending = bytes to result
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        type = "application/pdf"
                        addCategory(Intent.CATEGORY_OPENABLE)
                        putExtra(Intent.EXTRA_TITLE, "ficha-epi-${id.toLong()}.pdf")
                    }
                    startActivityForResult(intent, SAVE_PDF)
                } catch (error: RuntimeException) {
                    pending = null
                    result.error("picker_error", "Seletor de arquivos indisponível", null)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_PDF) return
        val (bytes, result) = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(false)
            return
        }
        Thread {
            try {
                val output = contentResolver.openOutputStream(uri)
                    ?: throw IOException("Não foi possível abrir o arquivo")
                output.use { it.write(bytes) }
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread { result.error("write_error", "Não foi possível salvar a ficha", null) }
            }
        }.start()
    }

    companion object {
        private const val SAVE_PDF = 4201
    }
}
