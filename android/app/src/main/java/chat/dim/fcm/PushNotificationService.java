package chat.dim.fcm;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.os.Build;

import androidx.annotation.NonNull;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import java.util.Map;

public class PushNotificationService extends FirebaseMessagingService {

    public static final String CHANNEL_ID = "offline_messages"; // Should match the string resource value
    private static final String CHANNEL_NAME = "Offline Messages";
    private static final String CHANNEL_DESCRIPTION = "Offline messages";

    private static void logInfo(String msg) {
        System.out.println("[Firebase] " + msg);
    }

    @Override
    public void onMessageReceived(@NonNull RemoteMessage message) {
        super.onMessageReceived(message);
        RemoteMessage.Notification notification = message.getNotification();
        if (notification == null) {
            logInfo("message error: " + message);
        } else {
            String title = notification.getTitle();
            String body = notification.getBody();
            logInfo("title: " + title + ", body: " + body);
        }

        Map<String, String> data = message.getData();
        logInfo("message data: " + data);
    }

    @Override
    public void onNewToken(@NonNull String token) {
        super.onNewToken(token);
        logInfo("new token: " + token);
        reportToken(token);
    }

    private static String deviceToken = null;

    private static void reportToken(String token) {
        String old = deviceToken;
        if (token == null || token.isEmpty()) {
            logInfo("token not found");
            return;
        } else if (old != null && old.equals(token)) {
            logInfo("token not changed: " + token);
            return;
        } else {
            deviceToken = token;
        }
        // TODO: report token to DIM bot
        logInfo("TODO: reporting token: " + token);
    }

    private static void createNotificationChannel(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_DEFAULT
            );
            channel.setDescription(CHANNEL_DESCRIPTION);

            NotificationManager notificationManager =
                    (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            notificationManager.createNotificationChannel(channel);
        }
    }

    public static void prepareNotification(Context context) {
        // prepare default channel
        createNotificationChannel(context);
        // check token
        FirebaseMessaging.getInstance().getToken().addOnCompleteListener(task -> {
            if (task.isSuccessful()) {
                // Get new FCM registration token
                reportToken(task.getResult());
            }
        });
    }

}
