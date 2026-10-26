package chat.dim.c2dm;

import android.content.Intent;

import androidx.annotation.NonNull;

import com.google.firebase.messaging.FirebaseMessagingService;

public class PushService extends FirebaseMessagingService {

    @Override
    public void onNewToken(@NonNull String token) {
        super.onNewToken(token);
        // Save the refreshed token and report it to the station.
        PushCenter center = PushCenter.getInstance();
        center.saveToken(token, this);
        center.reportToken(token, this);
    }

    @Override
    public void handleIntent(Intent intent) {
        super.handleIntent(intent);
        // apply badge count from message data
        AppBadge.handleIntent(intent, this);
    }

}
