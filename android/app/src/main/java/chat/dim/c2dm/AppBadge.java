package chat.dim.c2dm;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

import com.google.firebase.messaging.RemoteMessage;

import java.util.Map;

import chat.dim.type.Converter;
import chat.dim.utils.Log;
import me.leolin.shortcutbadger.ShortcutBadger;

class AppBadge {

   static void handleIntent(Intent intent, Context context) {
      try {
         // fetch badge count from message data
         int count = AppBadge.getCount(intent);
         if (count >= 0) {
            AppBadge.applyCount(count, context);
         }
      } catch (Exception e) {
         Log.error("failed to fetch badge count: " + e);
      }
   }

   static int getCount(Intent intent) {
      Bundle extra = intent.getExtras();
      if (extra == null) {
         return -1;
      }
      RemoteMessage message = new RemoteMessage(extra);
      RemoteMessage.Notification notification = message.getNotification();
      // 1. get from notification
      if (notification != null) {
         Integer count = notification.getNotificationCount();
         if (count != null && count >= 0) {
            return count;
         }
      }
      // 2. get from data
      Map<String, String> data = message.getData();
      Object value = data.get("badge_count");
      if (value == null) {
         value = data.get("badge");
      }
      return Converter.getInt(value, -1);
   }

   static void applyCount(int count, Context context) {
      if (count < 0) {
         Log.error("badge count error: " + count);
         return;
      }
      Log.info("apply badge count: " + count);
      ShortcutBadger.applyCount(context, count);
   }

   static void removeCount(Context context) {
      Log.info("clear badge count");
      ShortcutBadger.removeCount(context);
   }

}
