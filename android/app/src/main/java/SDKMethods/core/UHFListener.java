package SDKMethods.core;

/**
 * Listener interface for UHF RFID events
 */
public abstract class UHFListener {
    public abstract void onRead(String tagsJson);
    public abstract void onConnect(boolean isConnected, int powerLevel);
}

