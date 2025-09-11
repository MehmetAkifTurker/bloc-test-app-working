// package com.example.water_boiler_rfid_labeler;

// import android.os.Bundle;
// import android.util.Log;
// import android.view.KeyEvent;
// import io.flutter.embedding.android.FlutterActivity;
// import io.flutter.plugin.common.MethodChannel;

// public class MainActivity extends FlutterActivity {
//     private static final String CHANNEL = "com.example.my_rfid_plugin/key_events";

//     @Override
//     protected void onCreate(Bundle savedInstanceState) {
//         super.onCreate(savedInstanceState);
//         new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), CHANNEL).setMethodCallHandler(
//                 (call, result) -> {
//                     // Handle method calls from Flutter if needed
//                 });
//     }

//     @Override
//     public boolean onKeyDown(int keyCode, KeyEvent event) {
//         Log.d("MainActivity", "Key down: " + keyCode);
//         new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("onKeyDown",
//                 keyCode);
//         return super.onKeyDown(keyCode, event);
//     }

//     @Override
//     public boolean onKeyUp(int keyCode, KeyEvent event) {
//         Log.d("MainActivity", "Key up: " + keyCode);
//         new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("onKeyUp",
//                 keyCode);
//         return super.onKeyUp(keyCode, event);
//     }
// }
// package com.example.water_boiler_rfid_labeler;

// import android.os.Bundle;
// import android.util.Log;
// import android.view.KeyEvent;
// import io.flutter.embedding.android.FlutterActivity;
// import io.flutter.plugin.common.MethodChannel;

// public class MainActivity extends FlutterActivity {
// private static final String CHANNEL =
// "com.example.my_rfid_plugin/key_events";
// private MethodChannel keyChannel;

// @Override
// protected void onCreate(Bundle savedInstanceState) {
// super.onCreate(savedInstanceState);
// keyChannel = new MethodChannel(
// getFlutterEngine().getDartExecutor().getBinaryMessenger(),
// CHANNEL);
// }

// private boolean isScanKey(int code) {
// return code == 131 || code == 132 || code == 293 || code == 294;
// }

// @Override
// public boolean onKeyDown(int keyCode, KeyEvent event) {
// if (isScanKey(keyCode) && event.getRepeatCount() == 0) {
// Log.d("MainActivity", "Key down: " + keyCode);
// keyChannel.invokeMethod("onKeyDown", keyCode);
// return true; // olayı tükettik
// }
// return super.onKeyDown(keyCode, event);
// }

// @Override
// public boolean onKeyUp(int keyCode, KeyEvent event) {
// if (isScanKey(keyCode)) {
// Log.d("MainActivity", "Key up: " + keyCode);
// keyChannel.invokeMethod("onKeyUp", keyCode);
// return true; // olayı tükettik
// }
// return super.onKeyUp(keyCode, event);
// }
// }
package com.example.water_boiler_rfid_labeler;

import androidx.annotation.NonNull;
import android.util.Log;
import android.view.KeyEvent;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.my_rfid_plugin/key_events";
    private MethodChannel keyChannel;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        keyChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
    }

    private boolean isScanKey(int code) {
        // C66: 293/294 (soldaki/sağdaki), bazı cihazlarda 131/132
        return code == 293 || code == 294 || code == 131 || code == 132;
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        Log.d("MainActivity", "Key down: " + keyCode);
        if (isScanKey(keyCode) && keyChannel != null) {
            keyChannel.invokeMethod("onKeyDown", keyCode);
            return true; // olayı tükettik
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    public boolean onKeyUp(int keyCode, KeyEvent event) {
        Log.d("MainActivity", "Key up: " + keyCode);
        if (isScanKey(keyCode) && keyChannel != null) {
            keyChannel.invokeMethod("onKeyUp", keyCode);
            return true; // olayı tükettik
        }
        return super.onKeyUp(keyCode, event);
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        final int code = event.getKeyCode();
        final int action = event.getAction();

        // Geçici: tüm tuşları görmek için açın
        // Log.v("MainActivity", "dispatch: code=" + code + " action=" + action);

        if (isScanKey(code)) {
            if (action == KeyEvent.ACTION_DOWN && event.getRepeatCount() == 0) {
                Log.d("MainActivity", "Key down: " + code);
                if (keyChannel != null)
                    keyChannel.invokeMethod("onKeyDown", code);
                return true; // olayı tükettik
            } else if (action == KeyEvent.ACTION_UP) {
                Log.d("MainActivity", "Key up: " + code);
                if (keyChannel != null)
                    keyChannel.invokeMethod("onKeyUp", code);
                return true; // olayı tükettik
            }
        }
        return super.dispatchKeyEvent(event);
    }

}
