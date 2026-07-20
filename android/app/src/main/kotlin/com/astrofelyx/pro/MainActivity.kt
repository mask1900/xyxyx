package com.astrofelyx.pro

import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.SnapshotsClient
import com.google.android.gms.games.snapshot.SnapshotMetadataChange
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.Charset

/// Flutter <-> Play Games Services v2 (giris + Saved Games/Snapshot
/// bulut kaydi) arasindaki kucuk kopru. Sadece PlayGamesService.dart
/// tarafindan cagrilir; skor tablosu/basarim ICERMEZ (bilerek).
///
/// NOT: Bu dosya derlenip test edilmedi (bu ortamda Android SDK/emulator
/// yok) — flutlab.io gibi tarayici tabanli bir onizlemede DE calismaz,
/// gercek bir Android derlemesi/cihazi gerekir. `flutter build apk`
/// sirasinda bir API uyusmazligi cikarsa, hata mesajindaki metod/sinif
/// adini "Play Games Services v2 Snapshots" arayarak Google'in guncel
/// dokumantasyonuyla karsilastir; yapi ayni kalir, isimler ufak
/// degisebilir.
class MainActivity : FlutterActivity() {
    private val channelName = "space_sort/play_games"
    // Play Console'da olusturdugun oyunun ID'siyle karismamasi icin
    // sabit, aciklayici bir Snapshot adi.
    private val snapshotName = "space_sort_progress"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "signInSilently" -> signIn(result, silentOnly = true)
                    "signIn" -> signIn(result, silentOnly = false)
                    "saveProgress" -> {
                        val data = call.argument<String>("data") ?: ""
                        saveProgress(data, result)
                    }
                    "loadProgress" -> loadProgress(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun signIn(result: MethodChannel.Result, silentOnly: Boolean) {
        val signInClient = PlayGames.getGamesSignInClient(this)
        signInClient.isAuthenticated.addOnCompleteListener { task ->
            val alreadyAuthenticated = task.isSuccessful && task.result.isAuthenticated
            if (alreadyAuthenticated) {
                result.success(true)
                return@addOnCompleteListener
            }
            if (silentOnly) {
                // Sessiz modda: kullaniciya hicbir UI gostermeden birak,
                // sadece "baglı degil" sonucunu don.
                result.success(false)
                return@addOnCompleteListener
            }
            // Kullanici bizzat "Bağlan" butonuna bastı: Google'in giris
            // akisini goster.
            signInClient.signIn().addOnCompleteListener { signInTask ->
                val ok = signInTask.isSuccessful && signInTask.result.isAuthenticated
                result.success(ok)
            }
        }
    }

    private fun saveProgress(data: String, result: MethodChannel.Result) {
        val snapshotsClient = PlayGames.getSnapshotsClient(this)
        snapshotsClient
            .open(snapshotName, true, SnapshotsClient.RESOLUTION_POLICY_LONGEST_PLAYTIME)
            .addOnCompleteListener { task ->
                val snapshot = task.result?.data
                if (!task.isSuccessful || snapshot == null) {
                    result.success(false)
                    return@addOnCompleteListener
                }
                try {
                    snapshot.snapshotContents.writeBytes(data.toByteArray(Charset.forName("UTF-8")))
                    val metadataChange = SnapshotMetadataChange.Builder()
                        .setDescription("AstroFelyx - oyuncu ilerlemesi")
                        .build()
                    snapshotsClient.commitAndClose(snapshot, metadataChange)
                        .addOnCompleteListener { commitTask ->
                            result.success(commitTask.isSuccessful)
                        }
                } catch (e: Exception) {
                    result.success(false)
                }
            }
    }

    private fun loadProgress(result: MethodChannel.Result) {
        val snapshotsClient = PlayGames.getSnapshotsClient(this)
        snapshotsClient
            .open(snapshotName, true, SnapshotsClient.RESOLUTION_POLICY_LONGEST_PLAYTIME)
            .addOnCompleteListener { task ->
                val snapshot = task.result?.data
                if (!task.isSuccessful || snapshot == null) {
                    result.success(null)
                    return@addOnCompleteListener
                }
                try {
                    val bytes = snapshot.snapshotContents.readFully()
                    snapshotsClient.discardAndClose(snapshot)
                    val text = if (bytes == null) "" else String(bytes, Charset.forName("UTF-8"))
                    result.success(if (text.isEmpty()) null else text)
                } catch (e: Exception) {
                    result.success(null)
                }
            }
    }
}
