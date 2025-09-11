package com.example.my_rfid_plugin;




public abstract class UHFListener {
    abstract void onRead(String tagsJson);

    abstract void onConnect(boolean isConnected, int powerLevel);

}


