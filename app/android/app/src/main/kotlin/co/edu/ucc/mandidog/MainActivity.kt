package co.edu.ucc.mandidog

import android.app.Activity
import android.content.Intent
import androidx.activity.result.contract.ActivityResultContracts
import com.aiforpet.pet.check.ToothCameraActivity
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Puente hacia el SDK de AI for Pet (io.github.aiforpet-ttcare:scansdk-lib).
 *
 * Flutter llama `scanTeeth` por el canal [CHANNEL]. Aquí se abre la cámara de dientes del
 * SDK, que toma la foto, revisa su calidad y la analiza en los servidores de AI for Pet.
 * A Flutter vuelve el JSON del resultado, o null si el usuario cierra la cámara.
 */
class MainActivity : FlutterFragmentActivity() {

    private var pendingResult: MethodChannel.Result? = null

    private val scanLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { activityResult ->
        val result = pendingResult ?: return@registerForActivityResult
        pendingResult = null
        if (activityResult.resultCode == Activity.RESULT_OK) {
            result.success(activityResult.data?.getStringExtra("result"))
        } else {
            result.success(null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scanTeeth" -> scanTeeth(call, result)
            else -> result.notImplemented()
        }
    }

    private fun scanTeeth(call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("scan_in_progress", "Ya hay un escaneo en curso", null)
            return
        }
        val sdkKey = call.argument<String>("sdkKey")
        val userId = call.argument<String>("userId")
        val petId = call.argument<String>("petId")
        if (sdkKey.isNullOrBlank() || userId.isNullOrBlank() || petId.isNullOrBlank()) {
            result.error("invalid_arguments", "sdkKey, userId y petId son obligatorios", null)
            return
        }

        val intent = Intent(this, ToothCameraActivity::class.java).apply {
            putExtra("petType", "DOG")
            // Solo identificadores internos: AI for Pet no recibe nombre, correo ni raza.
            putExtra("userId", userId)
            putExtra("petId", petId)
            putExtra("sdkKey", sdkKey)
            // Sin cuestionario (no está en español) ni pantalla de resultado del SDK:
            // la app muestra su propio resultado con el aviso del veterinario.
            putExtra("enablesQuestionnaire", false)
            putExtra("enableResultView", false)
            putExtra("enablePdfShare", false)
            putExtra("enableMultiMode", false)
        }

        pendingResult = result
        try {
            scanLauncher.launch(intent)
        } catch (e: Exception) {
            pendingResult = null
            result.error("sdk_launch_failed", e.message, null)
        }
    }

    companion object {
        const val CHANNEL = "co.edu.ucc.mandidog/aiforpet"
    }
}
