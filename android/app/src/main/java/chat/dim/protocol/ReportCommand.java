package chat.dim.protocol;

import java.util.HashMap;
import java.util.Map;

/*
 *  Command message: {
 *      type : 0x88,
 *      sn   : 123,
 *
 *      command : "report",
 *      title   : "online",      // or "offline"
 *      //---- extra info
 *      time    : 1234567890,    // timestamp
 *  }
 */
public class ReportCommand {

    public static final String REPORT = "report";
    public static final String ONLINE = "online";
    public static final String OFFLINE = "offline";

    public static Map<String, Object> create(String title) {
        long now = System.currentTimeMillis();
        Map<String, Object> info = new HashMap<>();
        info.put("type", ContentType.COMMAND.value);
        info.put("time", now / 1000.0);
        info.put("sn", now);
        info.put("command", REPORT);
        info.put("title", title);
        return info;
    }
}
