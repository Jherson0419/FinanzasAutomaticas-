package com.finanzasautomaticas.finanzas_automaticas

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Fase 89: abre los ajustes de notificaciones de la app (reemplaza a
    // permission_handler, que solo se usaba para esto). El nombre del canal
    // y del método deben coincidir con `notificaciones_locales_plugin.dart`.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "finzo/ajustes")
            .setMethodCallHandler { call, result ->
                if (call.method == "abrirAjustesNotificaciones") {
                    result.success(abrirAjustesNotificaciones())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun abrirAjustesNotificaciones(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            // Antes de Android 8: la pantalla de detalles de la app.
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:$packageName"))
        }
        return try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: Exception) {
            false
        }
    }
}
