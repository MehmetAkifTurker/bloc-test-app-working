package SDKMethods.core;

import java.util.Map;

/**
 * Tag Key Constants for JSON serialization
 */
public class TagKey {
    public static final String ID = "KEY_ID";
    public static final String RSSI = "KEY_RSSI";
    public static final String EPC = "KEY_EPC";
    public static final String COUNT = "KEY_COUNT";

    public static String getTag(Map<String, Object> map) {
        return (String) map.get(EPC);
    }
}

