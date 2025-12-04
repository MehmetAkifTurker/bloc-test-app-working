package SDKMethods;

import androidx.annotation.NonNull;
import android.util.Log;
import android.view.KeyEvent;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.my_rfid_plugin/key_events";
    private MethodChannel keyChannel;
    private boolean scanKeyHeld = false;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        keyChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        
        // Manually register RFID plugin
        flutterEngine.getPlugins().add(new RfidC72Plugin());
    }

    private boolean isScanKey(int code) {
        // C66: 293/294 (soldaki/sağdaki), bazı cihazlarda 131/132
        return code == 293 || code == 294 || code == 131 || code == 132;
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        final int code = event.getKeyCode();
        final int action = event.getAction();

        if (isScanKey(code) && keyChannel != null) {
            if (action == KeyEvent.ACTION_DOWN) {
                if (scanKeyHeld) {
                    return true;
                }
                scanKeyHeld = true;
                Log.d("MainActivity", "Key down: " + code);
                keyChannel.invokeMethod("onKeyDown", code);
                return true;
            } else if (action == KeyEvent.ACTION_UP) {
                if (!scanKeyHeld) {
                    return true;
                }
                scanKeyHeld = false;
                Log.d("MainActivity", "Key up: " + code);
                keyChannel.invokeMethod("onKeyUp", code);
                return true;
            }
        }
        return super.dispatchKeyEvent(event);
    }
}

