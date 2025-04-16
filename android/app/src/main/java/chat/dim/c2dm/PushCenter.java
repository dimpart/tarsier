package chat.dim.c2dm;

import android.app.NotificationManager;
import android.content.Context;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;

import java.util.List;
import java.util.Map;

import chat.dim.channels.ChannelManager;
import chat.dim.protocol.ReportCommand;

public enum PushCenter {

    INSTANCE;

    public static PushCenter getInstance() {
        return INSTANCE;
    }

    PushCenter() {
    }

    boolean done = false;

    public static void register(Context context) {
        PushCenter center = getInstance();
        if (center.done) {
            logError("no need to register again");
            return;
        } else {
            center.done = true;
        }
        try {
            // 1.
            logInfo("initializing firebase app");
            center.initialize(context);
            // 2.
            logInfo("reporting device token");
            center.reportDeviceToken(context);
        } catch (Exception e) {
            logError("failed to prepare: " + e);
        }
    }

    static void logInfo(String message) {
        System.out.println("[Firebase]       | " + message);
    }
    static void logError(String message) {
        System.out.println("[Firebase] ERROR | " + message);
    }

    private void initialize(Context context) {
        List<FirebaseApp> apps = FirebaseApp.getApps(context);
        if (apps.isEmpty()) {
            FirebaseApp.initializeApp(context);
        } else {
            logError("firebase app initialized: " + apps.size());
        }
    }

    private void reportDeviceToken(Context context) {
        FirebaseMessaging messaging = FirebaseMessaging.getInstance();
        messaging.getToken().addOnCompleteListener(task -> {
            if (task.isSuccessful()) {
                // Get new FCM registration token
                reportToken(task.getResult(), context);
            } else {
                logError("failed to get token: " + task);
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

        logInfo("report token to: " + receiver + ", " + command);

        ChannelManager man = ChannelManager.getInstance();
        man.sessionChannel.sendCommand(command, receiver);
    }

    public static void clearNotifications(Context context) {
        NotificationManager notificationManager =
                (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (notificationManager != null) {
            logInfo("clearing all notifications");
            notificationManager.cancelAll();
        }
    }

}
