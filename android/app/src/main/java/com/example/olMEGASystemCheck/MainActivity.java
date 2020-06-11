package com.example.olMEGASystemCheck;

import android.Manifest;
import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.media.AudioFormat;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Message;
import android.os.Messenger;
import android.os.PowerManager;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.support.v7.app.AppCompatActivity;
import android.util.Log;
import android.view.View;
import android.widget.ImageView;
import android.widget.Switch;
import android.widget.Toast;

import com.example.olMEGASystemCheck.bluetoothspp.library.BluetoothSPP;

import java.io.DataOutputStream;
import java.io.File;
import java.io.FileDescriptor;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintWriter;
import java.nio.ByteBuffer;
import java.util.Scanner;

public class MainActivity extends AppCompatActivity {

    private final static String LOG = "SystemCheck";
    private static InputProfile mInputProfile = null;
    private ImageView mSymbol = null;
    private final static int MY_PERMISSIONS_READ_EXTERNAL_STORAGE = 0;
    private final static int MY_PERMISSIONS_WRITE_EXTERNAL_STORAGE = 1;
    private final static int MY_PERMISSIONS_RECEIVE_BOOT_COMPLETED = 2;
    private final static int MY_PERMISSIONS_RECORD_AUDIO = 3;
    private final static int MY_PERMISSIONS_VIBRATE = 4;
    private final static int MY_PERMISSIONS_WAKE_LOCK = 5;
    private final static int MY_PERMISSIONS_DISABLE_KEYGUARD = 6;
    final Messenger mActivityMessenger = new Messenger(new MessageHandler());
    private static String messageDump = "";
    private static Handler mTaskHandler = new Handler();
    private int checkInterval = 100;

    private com.example.olMEGASystemCheck.bluetoothspp.library.BluetoothSPP bt;
    private ConnectedThread mConnectedThread;
    private state myState = state.UNINITIALIZED;
    private Intent intentSelectDevice = null;
    private AudioFileIO fileIO;
    private  DataOutputStream outputStream;

    private PowerManager.WakeLock keepScreenOn;
    private PowerManager pm;
    private int nStartDelay = 1*1000;
    private int nMeasurementDelay = 11*1000;

    BroadcastReceiver mCommandReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            try {
                String data = intent.getStringExtra("do");
                Log.e(LOG, "DATA: " + data);
                switch (data) {
                    case "Start":
                        if (((Switch) findViewById(R.id.protocolSwitch)).isChecked() == false) {
                            mInputProfile = new InputProfile_RFCOMM(MainActivity.this, mActivityMessenger);
                            mInputProfile.registerClient();
                            mInputProfile.setInterface();
                        }
                        myState = state.MEASURING;
                        mTaskHandler.postDelayed(stopRecordingRunnable, nMeasurementDelay);
                        break;
                    case "Stop":
                        myState = state.STOP_MEASURING;
                        break;
                    case "Finished":
                        myState = state.FINISHED;
                        break;
                    case "Reset":
                        reset();
                        break;
                    case "StoreCalibration":
                        if (((Switch) findViewById(R.id.protocolSwitch)).isChecked()) {
                            obtainCalibration();
                        }
                        break;
                }
            } catch (Exception e) {
                Log.e(LOG, "Problem: " + e.toString());
            }
        }
    };

    public double[] obtainCalibration() {
        class Local {
            public byte [] convertDoubleToByteArray(double number) {
                ByteBuffer byteBuffer = ByteBuffer.allocate(Double.BYTES);
                byteBuffer.putDouble(number);
                return byteBuffer.array();
            }
            private byte[] createData(byte type, double value) {
                byte[] data = "C0000000000".getBytes();
                byte[] values = convertDoubleToByteArray(value);
                data[1] = type;
                data[10] = type;
                for (int count = 0; count < values.length; count++)
                {
                    data[2 + count] = values[count];
                    data[10] ^= values[count];
                }
                return data;
            }
        }
        // Obtain working Directory
        File dir = new File(Environment.getExternalStorageDirectory() + File.separator + "olMEGA" + File.separator + "calibration");
        // Address Basis File in working Directory
        File file = new File(dir, "calib.txt");
        double[] calib = new double[] {0.0f, 0.0f};
        try {
            Scanner sc = new Scanner(file);
            // we just need to use \\Z as delimiter
            sc.useDelimiter("\n");
            calib[0] = Float.valueOf(sc.next());
            calib[1] = Float.valueOf(sc.next());
            for (int i = 0; i < 2; i++) {
                Log.e(LOG, "CALIB: " + calib[i]);
            }
            while (mConnectedThread.calibValues[0] != calib[0] && mConnectedThread.calibValues[1] != calib[1]) {
                bt.send(new Local().createData((byte)'L', calib[0]), false);
                bt.send(new Local().createData((byte)'R', calib[1]), false);
                Thread.sleep(2000);
                mConnectedThread.initializeState = initState.WAITING_FOR_CALIBRATION_VALUES;
                Thread.sleep(2000);
            }
            Toast.makeText(this, "Calibration Values successfully stored!", Toast.LENGTH_LONG).show();
        } catch (Exception e) {}
        return calib;
    }

    public enum state {
        UNINITIALIZED,
        CHANGING_TO_RFCOMM,
        WAITING_IN__RFCOMM,
        CHANGING_TO_PHANTOM,
        WAITING_IN__PHANTOM,
        INIT_WAITING_FOR_MEASURING,
        WAITING_FOR_MEASURING,
        MEASURING,
        STOP_MEASURING,
        FINISHED
    }

    public state getState() {
        return myState;
    }

    public void startRecording() {
        if (myState == state.WAITING_FOR_MEASURING)
            myState = state.MEASURING;
    }

    public void stopRecording() {
        if (myState == state.MEASURING)
            myState = state.STOP_MEASURING;
    }


    private Runnable mSetTextRunnable = new Runnable() {
        @Override
        public void run() {

            switch (myState) {
                case CHANGING_TO_RFCOMM:
                    mSymbol.setImageResource(R.drawable.hourglass_snooze);
                    if (mConnectedThread != null) {
                        mConnectedThread = null;
                    }
                    if (bt != null)
                        bt.disconnect();
                    bt = null;
                    findViewById(R.id.btnActivate).setEnabled(true);
                    findViewById(R.id.btnLinkDevice).setEnabled(false);
                    myState = state.WAITING_IN__RFCOMM;
                    setMessageDump("Preparing");
                    break;
                case WAITING_IN__RFCOMM:
                    findViewById(R.id.btnLinkDevice).setEnabled(false);
                    findViewById(R.id.btnActivate).setEnabled(true);
                    mSymbol.setImageResource(R.drawable.hourglass_snooze);
                    if (((Switch) findViewById(R.id.protocolSwitch)).isChecked())
                        myState = state.CHANGING_TO_PHANTOM;
                    setMessageDump("Preparing");
                    break;
                case CHANGING_TO_PHANTOM:
                    mSymbol.setImageResource(R.drawable.hourglass_snooze);
                    initBluetooth();
                    findViewById(R.id.btnActivate).setEnabled(false);
                    findViewById(R.id.btnLinkDevice).setEnabled(true);
                    myState = state.WAITING_IN__PHANTOM;
                    setMessageDump("Preparing");
                    break;
                case WAITING_IN__PHANTOM:
                    findViewById(R.id.btnActivate).setEnabled(false);
                    if (!((Switch) findViewById(R.id.protocolSwitch)).isChecked())
                        myState = state.CHANGING_TO_RFCOMM;
                    if (mConnectedThread != null && mConnectedThread.initializeState == initState.INITIALIZED)
                        findViewById(R.id.btnActivate).setEnabled(true);
                    setMessageDump("Preparing");
                    break;
                case INIT_WAITING_FOR_MEASURING:
                    mSymbol.setImageResource(R.drawable.hourglass);
                    findViewById(R.id.btnLinkDevice).setEnabled(false);
                    findViewById(R.id.btnActivate).setEnabled(false);
                    findViewById(R.id.protocolSwitch).setEnabled(false);
                    myState = state.WAITING_FOR_MEASURING;
                    setMessageDump("Preparing");
                case WAITING_FOR_MEASURING:
                    if (((Switch) findViewById(R.id.protocolSwitch)).isChecked()) {
                        setMessageDump("Waiting;DEVICE=" + bt.getConnectedDeviceAddress() + ";");
                    }
                    else {
                        setMessageDump("Waiting");
                    }
                    break;
                case MEASURING:
                    mSymbol.setImageResource(R.drawable.mic);
                    setMessageDump("Measuring");
                    break;
                case STOP_MEASURING:
                    if (mInputProfile != null) {
                        mInputProfile.cleanUp();
                    }
                    myState = state.FINISHED;
                    break;
                case FINISHED:
                    mSymbol.setImageResource(R.drawable.check);
                    setMessageDump("Finished");
                    break;
            }
            mTaskHandler.postDelayed(mSetTextRunnable, checkInterval);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        registerReceiver(mCommandReceiver, new IntentFilter("command"));
        mTaskHandler.post(mSetTextRunnable);

        pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
        keepScreenOn = pm.newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK,"tpd");

        setContentView(R.layout.activity_main);
        ((Switch) findViewById(R.id.protocolSwitch)).setChecked(true);
        findViewById(R.id.btnLinkDevice).setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                Log.e(LOG, "Button Clicked");
                if (intentSelectDevice == null) {
                    intentSelectDevice = new Intent(getApplicationContext(), com.example.olMEGASystemCheck.bluetoothspp.library.DeviceList.class);
                    startActivityForResult(intentSelectDevice, com.example.olMEGASystemCheck.bluetoothspp.library.BluetoothState.REQUEST_CONNECT_DEVICE);
                }
            }
        });
        findViewById(R.id.btnActivate).setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                myState = state.INIT_WAITING_FOR_MEASURING;
            }
        });
        WifiManager wifiManager = (WifiManager) getApplicationContext().getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        if (wifiManager.isWifiEnabled()) {
            Toast.makeText(this, "WiFi is enabled!\nPlease disable for lossless transmission!", Toast.LENGTH_LONG).show();
        }
        mSymbol = findViewById(R.id.symbol);
        requestPermissions(MY_PERMISSIONS_RECORD_AUDIO);
        // Create home directory
        String path = AudioFileIO.getMainFolderPath();
        Log.e(LOG, "New path: " + path);
        myState = state.CHANGING_TO_PHANTOM;

        mSymbol.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                mTaskHandler.postDelayed(startRecordingRunnable, nStartDelay);
            }
        });

    }

    private Runnable startRecordingRunnable = new Runnable() {
        @Override
        public void run() {
            sendBroadcast(new Intent("command").putExtra("do","Start"));
            mSymbol.setOnClickListener(null);
        }
    };

    private Runnable stopRecordingRunnable = new Runnable() {
        @Override
        public void run() {
            sendBroadcast(new Intent("command").putExtra("do","Stop"));
            mSymbol.setOnClickListener(null);
        }
    };

    @Override
    protected void onResume() {
        super.onResume();
        if ((keepScreenOn != null) &&           // we have a WakeLock
                (keepScreenOn.isHeld() == false)) {  // but we don't hold it
            keepScreenOn.acquire();
        }
    }

    @Override
    protected void onStart() {
        super.onStart();
        if ((keepScreenOn != null) &&           // we have a WakeLock
                (keepScreenOn.isHeld() == false)) {  // but we don't hold it
            keepScreenOn.acquire();
        }
    }

    @Override
    protected void onRestart() {
        super.onRestart();
        if ((keepScreenOn != null) &&           // we have a WakeLock
                (keepScreenOn.isHeld() == false)) {  // but we don't hold it
            keepScreenOn.acquire();
        }
        if ((keepScreenOn != null) &&
                (keepScreenOn.isHeld() == true)) {
            keepScreenOn.release();
            keepScreenOn = null;
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        if ((keepScreenOn != null) &&
                (keepScreenOn.isHeld() == true)) {
            keepScreenOn.release();
            keepScreenOn = null;
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
    }

    @Override
    protected void onDestroy() {
        if (mConnectedThread != null) {
            mConnectedThread = null;
        }
        if (bt != null)
            bt.disconnect();
        bt = null;
        mTaskHandler.removeCallbacks(mSetTextRunnable);
        mInputProfile = null;
        unregisterReceiver(mCommandReceiver);
        super.onDestroy();

        if ((keepScreenOn != null) &&
                (keepScreenOn.isHeld() == true)) {
            keepScreenOn.release();
            keepScreenOn = null;
        }
    }

    @Override
    public synchronized void dump(String prefix, FileDescriptor fd, PrintWriter writer, String[] args) {
        writer.println(getMessageDump());
    }

    public synchronized static void setMessageDump(String message) {
        //Log.d(LOG, message);
        messageDump = message;
    }

    public synchronized static String getMessageDump() {
        return messageDump;
    }

    public void reset() {
        finishAffinity();
        Intent intent = new Intent(getApplicationContext(), MainActivity.class);
        startActivity(intent);
    }

    public void requestPermissions(int iPermission) {

        // TODO: Make array
        switch (iPermission) {
            case 0:
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED)
                    ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.READ_EXTERNAL_STORAGE}, MY_PERMISSIONS_READ_EXTERNAL_STORAGE);
                break;
            case 1:
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED)
                    ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, MY_PERMISSIONS_WRITE_EXTERNAL_STORAGE);
                break;
            case 2:
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_BOOT_COMPLETED) != PackageManager.PERMISSION_GRANTED)
                    ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.RECEIVE_BOOT_COMPLETED}, MY_PERMISSIONS_RECEIVE_BOOT_COMPLETED);
                break;
            case 3:
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED)
                    ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.RECORD_AUDIO}, MY_PERMISSIONS_RECORD_AUDIO);
                break;
            case 4:
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.VIBRATE) != PackageManager.PERMISSION_GRANTED)
                    ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.VIBRATE}, MY_PERMISSIONS_VIBRATE);
                break;
            case 5:
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.WAKE_LOCK) != PackageManager.PERMISSION_GRANTED)
                    ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.WAKE_LOCK}, MY_PERMISSIONS_WAKE_LOCK);
                break;
            case 6:
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.DISABLE_KEYGUARD) != PackageManager.PERMISSION_GRANTED)
                    ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.DISABLE_KEYGUARD}, MY_PERMISSIONS_DISABLE_KEYGUARD);
                break;
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String permissions[], int[] grantResults) {
        switch (requestCode) {
            case MY_PERMISSIONS_RECORD_AUDIO: {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(MY_PERMISSIONS_WRITE_EXTERNAL_STORAGE);
                } else {
                    requestPermissions(MY_PERMISSIONS_RECORD_AUDIO);
                }
                break;
            }
            case MY_PERMISSIONS_WRITE_EXTERNAL_STORAGE: {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(MY_PERMISSIONS_WRITE_EXTERNAL_STORAGE);
                } else if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(MY_PERMISSIONS_RECORD_AUDIO);
                }
                break;
            }
        }
    }

    class MessageHandler extends Handler {
        @Override
        public void handleMessage(Message msg) {
            Log.d(LOG, "Received Message: " + msg.what);
            switch (msg.what) {
                default:
                    super.handleMessage(msg);
                    break;
            }
        }
    }

    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == com.example.olMEGASystemCheck.bluetoothspp.library.BluetoothState.REQUEST_CONNECT_DEVICE && resultCode == Activity.RESULT_OK) {
            bt.connect(data);
            new Handler().postDelayed(new Runnable() {
                @Override
                public void run() {
                    bt.send("STOREMAC", false);
                    bt.send("STOREMAC", false);
                    new Handler().postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            bt.disconnect();
                            intentSelectDevice = null;
                        }
                    }, 2000);
                }
            }, 2000);
        }
        else
            intentSelectDevice = null;
    }

    private void initBluetooth() {
        bt = new com.example.olMEGASystemCheck.bluetoothspp.library.BluetoothSPP(this);
        if (bt.isBluetoothEnabled() == true) {
            bt.setBluetoothStateListener(new BluetoothSPP.BluetoothStateListener() {
                public void onServiceStateChanged(int state) {
                    PowerManager powerManager = (PowerManager) getSystemService(POWER_SERVICE);
                    PowerManager.WakeLock wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "MyApp::MyWakelockTag");
                    if (state == com.example.olMEGASystemCheck.bluetoothspp.library.BluetoothState.STATE_CONNECTED && bt != null) {
                        if (!wakeLock.isHeld()) wakeLock.acquire();
                        mConnectedThread = new ConnectedThread(bt.getBluetoothService().getConnectedThread().getInputStream());
                        mConnectedThread.setPriority(Thread.MAX_PRIORITY);
                        mConnectedThread.start();
                    } else {
                        if (mConnectedThread != null) {
                            mConnectedThread = null;
                        }
                        if (wakeLock.isHeld()) wakeLock.release();
                        if (state == com.example.olMEGASystemCheck.bluetoothspp.library.BluetoothState.STATE_CONNECTING) {
                        } else if (state == com.example.olMEGASystemCheck.bluetoothspp.library.BluetoothState.STATE_LISTEN) {
                        } else if (state == com.example.olMEGASystemCheck.bluetoothspp.library.BluetoothState.STATE_NONE) {
                        }
                    }
                }
            });
            bt.setupService();
            bt.startService(com.example.olMEGASystemCheck.bluetoothspp.library.BluetoothState.DEVICE_OTHER);
        } else {
            bt.enable();
            initBluetooth();
        }
    }

    private void AudioTransmissionStart() {
    }

    private void writeData(byte[] data) {
        try {
            if (myState == state.MEASURING && fileIO == null) {
                fileIO = new AudioFileIO();
                outputStream = fileIO.openDataOutStream(
                        16000,
                        2,
                        AudioFormat.ENCODING_PCM_16BIT,
                        true
                );
            }
            if (myState == state.MEASURING && fileIO != null)
            {
                if (myState == state.MEASURING) {
                    for (byte int16 : data) {
                        outputStream.write(int16);
                        outputStream.write(int16 >> 8);
                        outputStream.flush();
                    }
                }
            }
            if ((myState == state.STOP_MEASURING || myState == state.FINISHED) && fileIO != null) {
                fileIO.closeDataOutStream();
                fileIO = null;
            }
        }
        catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void AudioTransmissionEnd() {
        if (fileIO != null) {
            Log.d(LOG, "START fileIO.closeDataOutStream()");
            fileIO.closeDataOutStream();
        }
    }

    enum initState {UNINITIALIZED, WAITING_FOR_CALIBRATION_VALUES, WAITING_FOR_AUDIOTRANSMISSION, INITIALIZED, STOP}

    class ConnectedThread extends Thread {
        private static final int block_size = 64;
        private static final int RECORDER_SAMPLERATE = 16000;
        private short AudioVolume;
        private int AudioBufferSize = block_size * 4, BlockCount, lostBlockCount;
        public double[] calibValues = new double[]{Double.NaN, Double.NaN};
        private final InputStream mmInStream;
        public initState initializeState;
        boolean isRunning = true;

        ConnectedThread(InputStream stream) {
            mmInStream = stream;
        }

        public void run() {
            RingBuffer ringBuffer = new RingBuffer(AudioBufferSize * 2);
            int alivePingTimeout = 100, i, lastBlockNumber = 0, currBlockNumber = 0, additionalBytesCount = 0;
            byte[] data = new byte[1024], emptyAudioBlock = new byte[AudioBufferSize];
            byte checksum = 0;
            int timeoutBlockLimit = 500, millisPerBlock = block_size * 1000 / RECORDER_SAMPLERATE;
            BlockCount = 0;
            lostBlockCount = 0;
            initializeState = initState.UNINITIALIZED;
            Long lastBluetoothPingTimer = System.currentTimeMillis(), lastEmptyPackageTimer = System.currentTimeMillis(), lastStreamTimer = System.currentTimeMillis();
            try {
                while (isRunning) {
                    if (mmInStream.available() >= data.length) {
                        mmInStream.read(data, 0, data.length);
                        for (i = 0; i < data.length; i++) {
                            ringBuffer.addByte(data[i]);
                            checksum ^= ringBuffer.getByte(0);
                            if (ringBuffer.getByte(-2) == (byte) 0x00 && ringBuffer.getByte(-3) == (byte) 0x80) {
                                switch (initializeState){
                                    case UNINITIALIZED:
                                        switch (((ringBuffer.getByte(-4) & 0xFF) << 8) | (ringBuffer.getByte(-5) & 0xFF)) { // Check Protocol-Version
                                            case 1:
                                                calibValues[0] = 1.0; calibValues[1] = 1.0;
                                                additionalBytesCount = 12;
                                                initializeState = initState.WAITING_FOR_AUDIOTRANSMISSION;
                                                break;
                                            case 2:
                                                calibValues[0] = Double.NaN; calibValues[1] = Double.NaN;
                                                additionalBytesCount = 12;
                                                initializeState = initState.WAITING_FOR_CALIBRATION_VALUES;
                                                break;
                                        }
                                        break;
                                    case WAITING_FOR_CALIBRATION_VALUES:
                                        if (ringBuffer.getByte(-15) == (byte) 0xFF && ringBuffer.getByte(-16) == (byte) 0x7F && ringBuffer.getByte(-14) == (byte)'C' && (ringBuffer.getByte(-13) == (byte)'L' || ringBuffer.getByte(-13) == (byte)'R')) {
                                            byte[] values = new byte[8];
                                            byte ValuesChecksum = ringBuffer.getByte(-13);
                                            for (int count = 0; count < 8; count++)
                                            {
                                                values[count] = ringBuffer.getByte(-12 + count);
                                                ValuesChecksum ^= values[count];
                                            }
                                            if (ValuesChecksum == ringBuffer.getByte(- 4)) {
                                                if (ringBuffer.getByte(-13) == 'L')
                                                    calibValues[0] = ByteBuffer.wrap(values).getDouble();
                                                else if (ringBuffer.getByte(-13) == 'R')
                                                    calibValues[1] = ByteBuffer.wrap(values).getDouble();
                                                if (!Double.isNaN(calibValues[0]) && !Double.isNaN(calibValues[1])) {
                                                    if (!getApplicationInfo().loadLabel(getPackageManager()).toString().equals("olMEGASystemCheck")) {
                                                        if (calibValues[0] < calibValues[1]) {
                                                            calibValues[1] = Math.pow(10, (calibValues[0] - calibValues[1]) / 20.0);
                                                            calibValues[0] = 1;
                                                        } else {
                                                            calibValues[0] = Math.pow(10, (calibValues[1] - calibValues[0]) / 20.0);
                                                            calibValues[1] = 1;
                                                        }
                                                    }
                                                    initializeState = initState.WAITING_FOR_AUDIOTRANSMISSION;
                                                    Log.d("_IHA_", "START AUDIOTRANSMISSION");
                                                }
                                            }
                                        }
                                        else if (System.currentTimeMillis() - lastStreamTimer > 1000) {
                                            bt.send("GC", false);
                                            lastStreamTimer = System.currentTimeMillis();
                                            Log.d("_IHA_", "send GC");
                                        }
                                        break;
                                    case WAITING_FOR_AUDIOTRANSMISSION:
                                        if (ringBuffer.getByte(2 - (AudioBufferSize + additionalBytesCount)) == (byte) 0xFF && ringBuffer.getByte(1 - (AudioBufferSize + additionalBytesCount)) == (byte) 0x7F) {
                                            if (ringBuffer.getByte(0) == (checksum ^ ringBuffer.getByte(0))) {
                                                AudioTransmissionStart();
                                                initializeState = initState.INITIALIZED;
                                                currBlockNumber = ((ringBuffer.getByte(-6) & 0xFF) << 8) | (ringBuffer.getByte(-7) & 0xFF);
                                                lastBlockNumber = currBlockNumber;
                                            }
                                            checksum = 0;
                                        }
                                        break;
                                    case INITIALIZED:
                                        if (ringBuffer.getByte(2 - (AudioBufferSize + additionalBytesCount)) == (byte) 0xFF && ringBuffer.getByte(1 - (AudioBufferSize + additionalBytesCount)) == (byte) 0x7F) {
                                            if (ringBuffer.getByte(0) == (checksum ^ ringBuffer.getByte(0))) {
                                                AudioVolume = (short) (((ringBuffer.getByte(-8) & 0xFF) << 8) | (ringBuffer.getByte(-9) & 0xFF));
                                                currBlockNumber = ((ringBuffer.getByte(-6) & 0xFF) << 8) | (ringBuffer.getByte(-7) & 0xFF);
                                                if (currBlockNumber < lastBlockNumber && lastBlockNumber - currBlockNumber > currBlockNumber + (65536 - lastBlockNumber))
                                                    currBlockNumber += 65536;
                                                if (lastBlockNumber < currBlockNumber) {
                                                    BlockCount += currBlockNumber - lastBlockNumber;
                                                    lostBlockCount += currBlockNumber - lastBlockNumber - 1;
                                                    while (lastBlockNumber < currBlockNumber - 1) {
                                                        Log.d("_IHA_", "CurrentBlock: " + currBlockNumber + "\tLostBlocks: " + lostBlockCount);
                                                        writeData(emptyAudioBlock);
                                                        lastBlockNumber++;
                                                    }
                                                    lastBlockNumber = currBlockNumber % 65536;
                                                    if (!getApplicationInfo().loadLabel(getPackageManager()).toString().equals("olMEGASystemCheck")) {
                                                        for (int idx = 0; idx < AudioBufferSize / 2; idx++)
                                                            ringBuffer.setShort((short) (ringBuffer.getShort(3 - (AudioBufferSize + additionalBytesCount) + idx * 2) * calibValues[idx % 2]), 3 - (AudioBufferSize + additionalBytesCount) + idx * 2);
                                                    }
                                                    writeData(ringBuffer.data(3 - (AudioBufferSize + additionalBytesCount), AudioBufferSize));
                                                    lastStreamTimer = System.currentTimeMillis();
                                                } else
                                                    Log.d("_IHA_", "CurrentBlock: " + currBlockNumber + "\tTOO SLOW!");
                                            }
                                            checksum = 0;
                                        }
                                        break;
                                    case STOP:
                                        if (initializeState == initState.INITIALIZED) AudioTransmissionEnd();
                                        initializeState = initState.UNINITIALIZED;
                                        bt.getBluetoothService().connectionLost();
                                        bt.getBluetoothService().start(false);
                                }
                            }
                        }
                        lastEmptyPackageTimer = System.currentTimeMillis();
                    } else if (initializeState == initState.INITIALIZED && System.currentTimeMillis() - lastEmptyPackageTimer > timeoutBlockLimit) {
                        for (long count = 0; count < timeoutBlockLimit / millisPerBlock; count++) {
                            BlockCount++;
                            lostBlockCount++;
                            lastBlockNumber++;
                            writeData(emptyAudioBlock);
                        }
                        Log.d("_IHA_", "Transmission Timeout\t");
                        lastEmptyPackageTimer = System.currentTimeMillis();
                    }
                    if (initializeState == initState.INITIALIZED) {
                        if (System.currentTimeMillis() - lastBluetoothPingTimer > alivePingTimeout) {
                            bt.send(" ", false);
                            lastBluetoothPingTimer = System.currentTimeMillis();
                        }
                        if (System.currentTimeMillis() - lastStreamTimer > 5 * 1000) // 5 seconds
                        {
                            if (initializeState == initState.INITIALIZED) AudioTransmissionEnd();
                            initializeState = initState.UNINITIALIZED;
                            bt.getBluetoothService().connectionLost();
                            bt.getBluetoothService().start(false);
                        }
                    }

                }
            } catch (IOException e) {
            }
        }

        public void close() {
            isRunning = false;
        }

    }

}
