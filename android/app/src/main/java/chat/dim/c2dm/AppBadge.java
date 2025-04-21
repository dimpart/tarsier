package chat.dim.c2dm;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

import com.google.firebase.messaging.RemoteMessage;

import java.util.Date;
import java.util.Map;

import chat.dim.type.Converter;
import chat.dim.utils.Log;
import me.leolin.shortcutbadger.ShortcutBadger;

class AppBadge {

   static void handleIntent(Intent intent, Context context) {
      try {
         Bundle extra = intent.getExtras();
         if (extra == null) {
            return;
         }
         RemoteMessage message = new RemoteMessage(extra);
         Map<String, String> data = message.getData();
         // get message time
         Date when = Converter.getDateTime(data.get("time"), null);
         Date last = lastTime;
         // get message count
         int count = getCount(message.getNotification(), data);
         if (count < 0) {
            Log.warning("ignore message: " + data);
         } else if (when == null) {
            Log.warning("abnormal message: " + data);
            applyCount(count, context);
         } else if (last == null || last.before(when)) {
            Log.info("update message time: " + when);
            lastTime = when;
            applyCount(count, context);
         } else {
            Log.warning("ignore expired message: " + data);
         }
      } catch (Exception e) {
         Log.error("failed to fetch badge count: " + e);
      }
   }

   private static Date lastTime;

   private static int getCount(RemoteMessage.Notification notification, Map<String, String> data) {
      // 1. get from notification
      if (notification != null) {
         Integer count = notification.getNotificationCount();
         if (count != null && count >= 0) {
            return count;
         }
      }
      // 2. get from data
      Object value = data.get("badge_count");
      if (value == null) {
         value = data.get("badge");
      }
      return Converter.getInt(value, -1);
   }

   private static void applyCount(int count, Context context) {
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
