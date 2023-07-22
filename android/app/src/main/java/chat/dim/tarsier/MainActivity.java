package chat.dim.tarsier;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.os.Bundle;
import android.os.Environment;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.File;

import io.flutter.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

import chat.dim.CryptoPlugins;
import chat.dim.Register;
import chat.dim.channels.ChannelManager;
import chat.dim.filesys.LocalCache;
import chat.dim.http.UpdateManager;

public class MainActivity extends FlutterActivity {

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        prepareDirectories(this);

        CryptoPlugins.registerCryptoPlugins();

        Register.prepare();

        System.out.println("initialize flutter channels");
        ChannelManager manager = ChannelManager.getInstance();
        manager.initChannels(flutterEngine.getDartExecutor().getBinaryMessenger());
        // init audio recorder/player
        manager.audioChannel.initAudioPlayer(MainActivity.this);
        manager.audioChannel.initAudioRecorder(MainActivity.this);

    }

    private static void prepareDirectories(Context context) {
        File filesDir = null;
        File cacheDir = null;
        if (Environment.MEDIA_MOUNTED.equals(Environment.getExternalStorageState())) {
            // sdcard found, get external files/cache
            filesDir = context.getExternalFilesDir(null);
            cacheDir = context.getExternalCacheDir();
        }
        if (filesDir == null) {
            filesDir = context.getFilesDir();
            assert filesDir != null : "failed to get files directory";
        }
        if (cacheDir == null) {
            cacheDir = context.getCacheDir();
            assert cacheDir != null : "failed to get cache directory";
        }
        System.out.println("files dir: " + filesDir);
        System.out.println("cache dir: " + cacheDir);

        LocalCache cache = LocalCache.getInstance();
        cache.setCachesDirectory(filesDir.getAbsolutePath());
        cache.setTemporaryDirectory(cacheDir.getAbsolutePath());
    }

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        if (isApkInDebug(MainActivity.this)) {
            Log.w("INIT", "Application in DEBUG mode");
        } else {
            chat.dim.utils.Log.LEVEL = chat.dim.utils.Log.RELEASE;
            Log.w("INIT", "Application in RELEASE mode");
        }
        super.onCreate(savedInstanceState);

        UpdateManager manager = new UpdateManager(MainActivity.this);
        manager.checkUpdateInfo();
    }

    public static boolean isApkInDebug(Context context) {
        try {
            ApplicationInfo info = context.getApplicationInfo();
            return (info.flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
        } catch (Exception e) {
            Log.e("INIT", "failed to get debuggable");
            return false;
        }
    }

    static {

        chat.dim.utils.Log.LEVEL = chat.dim.utils.Log.DEVELOP;
        Log.w("INIT", "set Log.LEVEL = DEVELOP");

    }
}
