package com.example.my_rfid_plugin;

import android.content.Context;

import io.reactivex.Observer;
import io.reactivex.android.schedulers.AndroidSchedulers;
import io.reactivex.annotations.NonNull;
import io.reactivex.disposables.Disposable;
import io.reactivex.schedulers.Schedulers;
import io.reactivex.subjects.PublishSubject;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

public class RfidC72Plugin implements FlutterPlugin, MethodCallHandler {

    private static Context appContext;

    private static final String CHANNEL_WRITE_TAG2 = "writeTagADIConstruct2";
    private static PublishSubject<Boolean> connectedStatus = PublishSubject.create();
    private static PublishSubject<String> tagsStatus = PublishSubject.create();

    // For Flutter versions <= 1.12
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "rfid_c72_plugin");
        initConnectedEvent(registrar.messenger());
        initReadEvent(registrar.messenger());
        channel.setMethodCallHandler(new RfidC72Plugin());

        UHFHelper.getInstance().init(registrar.context());
        UHFHelper.getInstance().setUhfListener(new UHFListener() {
            @Override
            public void onRead(String tagsJson) {
                // Forward tag data to stream
                tagsStatus.onNext(tagsJson);
            }

            @Override
            public void onConnect(boolean isConnected, int powerLevel) {
                connectedStatus.onNext(isConnected);
            }
        });
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        final MethodChannel channel = new MethodChannel(binding.getBinaryMessenger(), "rfid_c72_plugin");
        final EventChannel locationChannel = new EventChannel(binding.getBinaryMessenger(), "LocationStatus");
        locationChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                UHFHelper.setLocationSink(events); // <-- set sink
            }

            @Override
            public void onCancel(Object arguments) {
                UHFHelper.setLocationSink(null);
            }
        });
        initConnectedEvent(binding.getBinaryMessenger());
        initReadEvent(binding.getBinaryMessenger());
        channel.setMethodCallHandler(new RfidC72Plugin());
        appContext = binding.getApplicationContext();
        UHFHelper.getInstance().init(appContext);

        Context applicationContext = binding.getApplicationContext();
        UHFHelper.getInstance().init(applicationContext);
        UHFHelper.getInstance().setUhfListener(new UHFListener() {
            @Override
            public void onRead(String tagsJson) {
                // Forward tag data to stream
                tagsStatus.onNext(tagsJson);
            }

            @Override
            public void onConnect(boolean isConnected, int powerLevel) {
                connectedStatus.onNext(isConnected);
            }
        });
    }

    private static void initConnectedEvent(BinaryMessenger messenger) {
        final EventChannel connectedChannel = new EventChannel(messenger, "ConnectedStatus");
        connectedChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, final EventChannel.EventSink eventSink) {
                connectedStatus
                        .subscribeOn(Schedulers.newThread())
                        .observeOn(AndroidSchedulers.mainThread())
                        .subscribe(new Observer<Boolean>() {
                            @Override
                            public void onSubscribe(@NonNull Disposable d) {
                            }

                            @Override
                            public void onNext(@NonNull Boolean isConnected) {
                                eventSink.success(isConnected);
                            }

                            @Override
                            public void onError(@NonNull Throwable e) {
                            }

                            @Override
                            public void onComplete() {
                            }
                        });
            }

            @Override
            public void onCancel(Object arguments) {
            }
        });
    }

    private static void initReadEvent(BinaryMessenger messenger) {
        final EventChannel readChannel = new EventChannel(messenger, "TagsStatus");
        readChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, final EventChannel.EventSink eventSink) {
                tagsStatus
                        .subscribeOn(Schedulers.newThread())
                        .observeOn(AndroidSchedulers.mainThread())
                        .subscribe(new Observer<String>() {
                            @Override
                            public void onSubscribe(@NonNull Disposable d) {
                            }

                            @Override
                            public void onNext(@NonNull String tagJson) {
                                eventSink.success(tagJson);
                            }

                            @Override
                            public void onError(@NonNull Throwable e) {
                            }

                            @Override
                            public void onComplete() {
                            }
                        });
            }

            @Override
            public void onCancel(Object arguments) {
            }
        });
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        handleMethods(call, result);
    }

    private void handleMethods(MethodCall call, Result result) {
        switch (call.method) {
            case "getPlatformVersion":
                result.success("Android " + android.os.Build.VERSION.RELEASE);
                break;
            case "isStarted":
                result.success(UHFHelper.getInstance().isStarted());
                break;
            case "startSingle":
                result.success(UHFHelper.getInstance().start(true));
                break;
            case "startContinuous":
            case "startContinuous2":
                result.success(UHFHelper.getInstance().start(false));
                break;
            case "stop":
                result.success(UHFHelper.getInstance().stop());
                break;
            case "clearData":
                UHFHelper.getInstance().clearData();
                result.success(true);
                break;
            case "isEmptyTags":
                result.success(UHFHelper.getInstance().isEmptyTags());
                break;
            case "close":
                UHFHelper.getInstance().close();
                result.success(true);
                break;
            case "connect":
                result.success(UHFHelper.getInstance().connect());
                break;
            case "isConnected":
                result.success(UHFHelper.getInstance().isConnected());
                break;
            case "setPowerLevel":
                String pwr = call.argument("value");
                result.success(UHFHelper.getInstance().setPowerLevel(pwr));
                break;
            case "setWorkArea":
                String wa = call.argument("value");
                result.success(UHFHelper.getInstance().setWorkArea(wa));
                break;
            case "connectBarcode":
                result.success(UHFHelper.getInstance().connectBarcode());
                break;
            case "scanBarcode":
                result.success(UHFHelper.getInstance().scanBarcode());
                break;
            case "stopScan":
                result.success(UHFHelper.getInstance().stopScan());
                break;
            case "closeScan":
                result.success(UHFHelper.getInstance().closeScan());
                break;
            case "readBarcode":
                result.success(UHFHelper.getInstance().readBarcode());
                break;
            case "playSound":
                result.success(UHFHelper.getInstance().playSound());
                break;
            case "getPowerLevel":
                result.success(UHFHelper.getInstance().getPowerLevel());
                break;
            case "getFrequencyMode":
                result.success(UHFHelper.getInstance().getFrequencyMode());
                break;
            case "getTemperature":
                result.success(UHFHelper.getInstance().getTemperature());
                break;
            case CHANNEL_WRITE_TAG2: {
                String partNumber = call.argument("partNumber");
                String serialNumber = call.argument("serialNumber");
                if (partNumber != null && serialNumber != null) {
                    boolean ok = UHFHelper.getInstance().writeTagADIConstruct2(
                            partNumber.toUpperCase(),
                            serialNumber.toUpperCase());
                    result.success(ok);
                } else {
                    result.error("INVALID_ARGUMENTS", "Part Number and Serial Number required", null);
                }
                break;
            }
            // case "programConstruct2Epc": {
            // String pn = call.argument("partNumber");
            // String sn = call.argument("serialNumber");
            // String manager6 = call.argument("manager6");
            // String accessPwd = call.argument("accessPwd");
            // boolean ok = UHFHelper.getInstance().programConstruct2Epc(
            // pn.toUpperCase(), sn.toUpperCase(), manager6, accessPwd);
            // result.success(ok);
            // break;
            // }
            case "programConstruct2Epc": {
                String partNumber = call.argument("partNumber");
                String serialNumber = call.argument("serialNumber");
                String manager = call.argument("manager");
                String accessPwd = call.argument("accessPwd");
                Integer filter = call.argument("filter");

                boolean ok = UHFHelper.getInstance().programConstruct2Epc(
                        partNumber != null ? partNumber : "",
                        serialNumber != null ? serialNumber : "",
                        manager != null ? manager : " TG424",
                        accessPwd != null ? accessPwd : "00000000",
                        filter != null ? filter : 0);
                result.success(ok);
                break;
            }

            case "readSingleTagEpc": {
                String epc = UHFHelper.getInstance().readSingleTagEPCWithRetry();
                result.success(epc);
                break;
            }

            case "readSingleTagEpcBasic": {
                String epc = UHFHelper.getInstance().readSingleTagEPC();
                result.success(epc);
                break;
            }

            case "writeAtaUserMemoryWithPayload": {
                String manufacturer = call.argument("manufacturer");
                String productName = call.argument("productName"); // null olabilir
                String partNumber = call.argument("partNumber");
                String serialNumber = call.argument("serialNumber");
                String manufactureDate = call.argument("manufactureDate");

                boolean ok = UHFHelper.getInstance().writeAtaUserMemoryWithPayload(
                        manufacturer != null ? manufacturer : "",
                        productName != null ? productName : "",
                        partNumber != null ? partNumber : "",
                        serialNumber != null ? serialNumber : "",
                        manufactureDate != null ? manufactureDate : "");
                result.success(ok);
                break;
            }

            case "readUserMemory": {
                String userMemory = UHFHelper.getInstance().readUserMemory();
                result.success(userMemory);
                break;
            }

            case "readUserMemoryForEpc": {
                String epc = call.argument("epc");
                String userMemory = UHFHelper.getInstance().readUserMemoryForEpc(epc);
                result.success(userMemory);
                break;
            }

            case "startLocation": {
                String label = call.argument("label");
                int bank = call.argument("bank");
                int ptr = call.argument("ptr");

                boolean ok = UHFHelper.getInstance().startLocation(appContext, label, bank, ptr);
                result.success(ok);
                break;
            }
            case "stopLocation":
                boolean stopped = UHFHelper.getInstance().stopLocation();
                result.success(stopped);
                break;

            case "configureChipAta": {
                String recordType = call.argument("recordType");
                Integer epcWords = call.argument("epcWords");
                Integer userWords = call.argument("userWords");
                Integer permalockWords = call.argument("permalockWords");
                Boolean enablePermalock = call.argument("enablePermalock");
                Boolean lockEpc = call.argument("lockEpc");
                Boolean lockUser = call.argument("lockUser");
                String accessPwd = call.argument("accessPwd");

                boolean ok = UHFHelper.getInstance().prepareAtaChip(
                        recordType,
                        epcWords != null ? epcWords : 12,
                        userWords != null ? userWords : 0,
                        permalockWords != null ? permalockWords : 0,
                        enablePermalock != null && enablePermalock,
                        lockEpc != null && lockEpc,
                        lockUser != null && lockUser,
                        accessPwd != null ? accessPwd : "00000000");
                result.success(ok);
                break;
            }
            case "getCurrentTags": {
                String json = UHFHelper.getInstance().getCurrentTagsJson();
                result.success(json);
                break;
            }
            case "readUserFieldsForEpc": {
                String epc = call.argument("epc");
                String json = UHFHelper.getInstance().readUserFieldsForEpc(epc);
                result.success(json);
                break;
            }

            default:
                result.notImplemented();
                break;

        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        // no-op
    }
}
