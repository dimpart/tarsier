package chat.dim.c2dm;

import android.app.NotificationManager;
import android.content.Context;
import android.os.Build;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;

import java.util.List;
import java.util.Map;

import chat.dim.channels.ChannelManager;
import chat.dim.protocol.ReportCommand;
import chat.dim.utils.Log;

public enum PushCenter {

    INSTANCE;

    static PushCenter getInstance() {
        return INSTANCE;
    }

    PushCenter() {
    }

    boolean done = false;

    public static void register(Context context) {
        try {
            PushCenter center = getInstance();
            if (center.done) {
                Log.warning("no need to register again");
                return;
            } else {
                center.done = true;
            }
            // 1.
            Log.info("initializing firebase app");
            center.initialize(context);
            // 2.
            Log.info("reporting device token");
            center.reportDeviceToken(context);
        } catch (Exception e) {
            Log.error("failed to prepare: " + e);
        }
    }

    public static void cleanup(Context context) {
        try {
            // clear notifications
            PushCenter center = getInstance();
            center.clearNotifications(context);
            // clear badge count
            AppBadge.removeCount(context);
        } catch (Exception e) {
            Log.error("failed to clear notifications: " + e);
        }
    }

    private void initialize(Context context) {
        List<FirebaseApp> apps = FirebaseApp.getApps(context);
        if (apps.isEmpty()) {
            FirebaseApp.initializeApp(context);
        } else {
            Log.error("firebase app initialized: " + apps.size());
        }
    }

    private void reportDeviceToken(Context context) {
        FirebaseMessaging messaging = FirebaseMessaging.getInstance();
        messaging.getToken().addOnCompleteListener(task -> {
            if (task.isSuccessful()) {
                // Get new FCM registration token
                reportToken(task.getResult(), context);
            } else {
                Log.error("failed to get token: " + task);
            }
        });
    }

    private void reportToken(String token, Context context) {
        final String app = context.getPackageName();
        final String receiver = "c2dm@anywhere";

        Map<String, Object> command = ReportCommand.create("c2dm");
        command.put("platform", "Android");
        command.put("channel", "firebase");
        command.put("token", token);
        command.put("topic", app);
        // system
        command.put("system_version", Build.VERSION.RELEASE);
        command.put("sdk_version", Build.VERSION.SDK_INT);
        // device
        command.put("manufacturer", Build.MANUFACTURER);
        command.put("brand", Build.BRAND);
        command.put("model", Build.MODEL);
        command.put("device", Build.DEVICE);
        command.put("product", Build.PRODUCT);
        command.put("hardware", Build.HARDWARE);

        Log.info("report token to: " + receiver + ", " + command);

        ChannelManager man = ChannelManager.getInstance();
        man.sessionChannel.sendCommand(command, receiver);
    }

    private void clearNotifications(Context context) {
        NotificationManager notificationManager =
                (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (notificationManager != null) {
            Log.info("clearing all notifications");
            notificationManager.cancelAll();
        }
    }

}
