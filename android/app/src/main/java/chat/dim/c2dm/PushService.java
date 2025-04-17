package chat.dim.c2dm;

import android.content.Intent;

import androidx.annotation.NonNull;

import com.google.firebase.messaging.FirebaseMessagingService;

import chat.dim.utils.Log;

public class PushService extends FirebaseMessagingService {

    @Override
    public void onNewToken(@NonNull String token) {
        super.onNewToken(token);
        // TODO: report device token
        Log.warning("new token: " + token);
    }

    @Override
    public void handleIntent(Intent intent) {
        super.handleIntent(intent);
        // apply badge count from message data
        AppBadge.handleIntent(intent, this);
    }

}
