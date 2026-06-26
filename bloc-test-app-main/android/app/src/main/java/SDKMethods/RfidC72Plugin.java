package SDKMethods;

import android.content.Context;

import io.reactivex.Observable;
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

import SDKMethods.core.UHFListener;
import SDKMethods.location.LocationManager;

/**
 * Flutter Plugin for RFID C72 Device
 */
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
        UHFHelper.getInstance().setUhfListener(createUhfListener());
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        final MethodChannel channel = new MethodChannel(binding.getBinaryMessenger(), "rfid_c72_plugin");

        // Location event channel
        final EventChannel locationChannel = new EventChannel(binding.getBinaryMessenger(), "LocationStatus");
        locationChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                LocationManager.setLocationSink(events);
            }

            @Override
            public void onCancel(Object arguments) {
                LocationManager.setLocationSink(null);
            }
        });

        initConnectedEvent(binding.getBinaryMessenger());
        initReadEvent(binding.getBinaryMessenger());
        channel.setMethodCallHandler(new RfidC72Plugin());

        appContext = binding.getApplicationContext();
        UHFHelper.getInstance().init(appContext);
        UHFHelper.getInstance().setUhfListener(createUhfListener());
    }

    private static UHFListener createUhfListener() {
        return new UHFListener() {
            @Override
            public void onRead(String tagsJson) {
                tagsStatus.onNext(tagsJson);
            }

            @Override
            public void onConnect(boolean isConnected, int powerLevel) {
                connectedStatus.onNext(isConnected);
            }
        };
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
                // Run heavy UHF initialization on background thread
                Observable.fromCallable(() -> UHFHelper.getInstance().connect())
                    .subscribeOn(Schedulers.io())
                    .observeOn(AndroidSchedulers.mainThread())
                    .subscribe(success -> result.success(success), 
                               error -> result.success(false));
                break;
            case "isConnected":
                result.success(UHFHelper.getInstance().isConnected());
                break;
            case "setPowerLevel":
                // Run on background thread
                final String powerValue = call.argument("value");
                Observable.fromCallable(() -> UHFHelper.getInstance().setPowerLevel(powerValue))
                    .subscribeOn(Schedulers.io())
                    .observeOn(AndroidSchedulers.mainThread())
                    .subscribe(success -> result.success(success), 
                               error -> result.success(false));
                break;
            case "setWorkArea":
                result.success(UHFHelper.getInstance().setWorkArea(call.argument("value")));
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
            case "disableLaser":
                UHFHelper.getInstance().disableLaser();
                result.success(true);
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
                    result.success(UHFHelper.getInstance().writeTagADIConstruct2(
                            partNumber.toUpperCase(), serialNumber.toUpperCase()));
                } else {
                    result.error("INVALID_ARGUMENTS", "Part Number and Serial Number required", null);
                }
                break;
            }
            case "programConstruct1Epc": {
                // Construct 1: Only Serial Number (no Part Number) - for Utility tags
                String serialNumber = call.argument("serialNumber");
                String manager = call.argument("manager");
                String accessPwd = call.argument("accessPwd");
                Integer filter = call.argument("filter");
                result.success(UHFHelper.getInstance().programConstruct1Epc(
                        serialNumber != null ? serialNumber : "",
                        manager != null ? manager : " TG424",
                        accessPwd != null ? accessPwd : "00000000",
                        filter != null ? filter : 0));
                break;
            }
            case "programConstruct2Epc": {
                // Construct 2: Part Number + Serial Number - standard format
                String partNumber = call.argument("partNumber");
                String serialNumber = call.argument("serialNumber");
                String manager = call.argument("manager");
                String accessPwd = call.argument("accessPwd");
                Integer filter = call.argument("filter");
                result.success(UHFHelper.getInstance().programConstruct2Epc(
                        partNumber != null ? partNumber : "",
                        serialNumber != null ? serialNumber : "",
                        manager != null ? manager : " TG424",
                        accessPwd != null ? accessPwd : "00000000",
                        filter != null ? filter : 0));
                break;
            }
            case "readSingleTagEpc":
                result.success(UHFHelper.getInstance().readSingleTagEPCWithRetry());
                break;
            case "readSingleTagEpcBasic":
                result.success(UHFHelper.getInstance().readSingleTagEPC());
                break;
            case "readSingleTagWithTid":
                result.success(UHFHelper.getInstance().readSingleTagWithTid());
                break;
            case "readSingleTagMeta":
                result.success(UHFHelper.getInstance().readSingleTagMeta());
                break;
            case "readSingleTagBasicJson":
                result.success(UHFHelper.getInstance().readSingleTagBasicJson());
                break;
            case "readUserMemoryForTid":
                result.success(UHFHelper.getInstance().readUserMemoryForTid(call.argument("tid")));
                break;
            case "readUserMemoryForEpcFull":
                result.success(UHFHelper.getInstance().readUserMemoryForEpcFull(call.argument("epc")));
                break;
            case "readFullTidForEpc":
                result.success(UHFHelper.getInstance().readFullTidForEpc(call.argument("epc")));
                break;
            case "readExtendedTidForEpc":
                result.success(UHFHelper.getInstance().readExtendedTidForEpc(call.argument("epc")));
                break;
            case "readUserMemoryForTidStrict":
                result.success(UHFHelper.getInstance().readUserMemoryForTidStrict(call.argument("tid")));
                break;
            case "diagnosticReadSingleTag":
                result.success(UHFHelper.getInstance().diagnosticReadSingleTag());
                break;
            case "writeAtaUserMemoryWithPayload": {
                String manufacturer = call.argument("manufacturer");
                String productName = call.argument("productName");
                String partNumber = call.argument("partNumber");
                String serialNumber = call.argument("serialNumber");
                String manufactureDate = call.argument("manufactureDate");
                String expireDate = call.argument("expireDate");
                result.success(UHFHelper.getInstance().writeAtaUserMemoryWithPayload(
                        manufacturer != null ? manufacturer : "",
                        productName != null ? productName : "",
                        partNumber != null ? partNumber : "",
                        serialNumber != null ? serialNumber : "",
                        manufactureDate != null ? manufactureDate : "",
                        expireDate != null ? expireDate : ""));
                break;
            }
            case "updateLifecycleRecord": {
                String epcHex = call.argument("epcHex");
                result.success(UHFHelper.getInstance().updateLifecycleRecord(
                        epcHex != null ? epcHex : "",
                        call.argument("currentPartNumber"),
                        call.argument("partModLevel"),
                        call.argument("expirationDate"),
                        call.argument("certificateNumber"),
                        call.argument("lastOverhaulDate")));
                break;
            }
            case "readUserMemory":
                result.success(UHFHelper.getInstance().readUserMemory());
                break;
            case "readUserMemoryForEpc":
                result.success(UHFHelper.getInstance().readUserMemoryForEpcWithFilter(call.argument("epc")));
                break;
            case "startLocation": {
                String label = call.argument("label");
                int bank = call.argument("bank");
                int ptr = call.argument("ptr");
                result.success(UHFHelper.getInstance().startLocation(appContext, label, bank, ptr));
                break;
            }
            case "stopLocation":
                result.success(UHFHelper.getInstance().stopLocation());
                break;
            case "setLocationSoundEnabled": {
                Boolean enabled = call.argument("enabled");
                UHFHelper.getInstance().setLocationSoundEnabled(enabled != null && enabled);
                result.success(true);
                break;
            }
            case "configureChipAta": {
                String recordType = call.argument("recordType");
                Integer epcWords = call.argument("epcWords");
                Integer userWords = call.argument("userWords");
                Integer permalockWords = call.argument("permalockWords");
                Boolean enablePermalock = call.argument("enablePermalock");
                Boolean lockEpc = call.argument("lockEpc");
                Boolean lockUser = call.argument("lockUser");
                String accessPwd = call.argument("accessPwd");
                result.success(UHFHelper.getInstance().prepareAtaChip(
                        recordType,
                        epcWords != null ? epcWords : 12,
                        userWords != null ? userWords : 0,
                        permalockWords != null ? permalockWords : 0,
                        enablePermalock != null && enablePermalock,
                        lockEpc != null && lockEpc,
                        lockUser != null && lockUser,
                        accessPwd != null ? accessPwd : "00000000"));
                break;
            }
            case "getCurrentTags":
                result.success(UHFHelper.getInstance().getCurrentTagsJson());
                break;
            case "readUserFieldsForEpc":
                result.success(UHFHelper.getInstance().readUserFieldsForEpc(call.argument("epc")));
                break;
            case "setAccessPassword": {
                String oldPassword = call.argument("oldPassword");
                String newPassword = call.argument("newPassword");
                result.success(UHFHelper.getInstance().setAccessPassword(
                        oldPassword != null ? oldPassword : "00000000",
                        newPassword != null ? newPassword : "00000001"));
                break;
            }
            case "lockUserMemory": {
                String accessPwd = call.argument("accessPwd");
                Boolean permanent = call.argument("permanent");
                result.success(UHFHelper.getInstance().lockUserMemory(
                        accessPwd != null ? accessPwd : "00000000",
                        permanent != null && permanent));
                break;
            }
            case "lockEpcMemory": {
                String accessPwd = call.argument("accessPwd");
                Boolean permanent = call.argument("permanent");
                result.success(UHFHelper.getInstance().lockEpcMemory(
                        accessPwd != null ? accessPwd : "00000000",
                        permanent != null && permanent));
                break;
            }
            case "permalockBirthRecord": {
                String accessPwd = call.argument("accessPwd");
                Integer startWord = call.argument("startWord");
                Integer wordCount = call.argument("wordCount");
                result.success(UHFHelper.getInstance().permalockUserBlocks(
                        accessPwd != null ? accessPwd : "00000000",
                        startWord != null ? startWord : 0,
                        wordCount != null ? wordCount : 12));
                break;
            }
            case "getCalculatedPermalockWords":
                // Get the recommended permalock size from last write operation
                result.success(UHFHelper.getInstance().getCalculatedPermalockWords());
                break;
            case "readBlockLockStatus": {
                // Read block permalock status for a tag
                String epcHex = call.argument("epc");
                Integer blockCount = call.argument("blockCount");
                java.util.Map<String, Object> lockStatus = UHFHelper.getInstance().readBlockLockStatus(
                        epcHex != null ? epcHex : "",
                        blockCount != null ? blockCount : 4);
                if (lockStatus != null) {
                    result.success(new org.json.JSONObject(lockStatus).toString());
                } else {
                    result.success(null);
                }
                break;
            }
            case "parseAtaLockFlags": {
                // Parse ATA Spec 2000 lock flags from USER memory
                String userHex = call.argument("userHex");
                java.util.Map<String, Object> flags = UHFHelper.parseAtaLockFlags(userHex);
                if (flags != null) {
                    result.success(new org.json.JSONObject(flags).toString());
                } else {
                    result.success(null);
                }
                break;
            }
            case "setFilterValueMask": {
                Integer filterValue = call.argument("filterValue");
                result.success(UHFHelper.getInstance().setFilterValueMask(
                        filterValue != null ? filterValue : -1));
                break;
            }
            case "clearAllFilters":
                result.success(UHFHelper.getInstance().clearAllFilters());
                break;
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
