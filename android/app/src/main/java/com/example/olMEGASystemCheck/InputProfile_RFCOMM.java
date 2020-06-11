package com.example.olMEGASystemCheck;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothClass;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Messenger;
import android.os.Parcelable;
import android.preference.PreferenceManager;
import android.util.Log;

import com.example.olMEGASystemCheck.MainActivity;

import java.lang.reflect.Method;
import java.util.Set;
import java.util.UUID;

public class InputProfile_RFCOMM implements InputProfile {

    private static final UUID MY_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");
    private final String INPUT_PROFILE = "RFCOMM";
    ConnectedThread mConnectedThread = null;
    private BluetoothAdapter mBluetoothAdapter;
    private BluetoothDevice mBluetoothDevice;
    private BluetoothSocket mSocket;
    private MainActivity mContext;
    private Messenger mActivityMessenger;
    private String LOG = "InputProfile_RFCOMM";

    private Handler mTaskHandler = new Handler();
    private int mWaitInterval = 200;
    private int mReleaseInterval = 0;
    private boolean mIsBound = false;
    private int mChunklengthInS = 120;
    private boolean mIsWave = true;
    private boolean mKeepOpen = false;


    private final BroadcastReceiver mUUIDReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            BluetoothDevice deviceExtra =
                    intent.getParcelableExtra("android.bluetooth.device.extra.DEVICE");
            Parcelable[] uuidExtra =
                    intent.getParcelableArrayExtra("android.bluetooth.device.extra.UUID");

            Log.e(LOG, "GOT SOMETHING: " + deviceExtra);

        }
    };

    // This Runnable has the purpose of delaying a release of mConnectedThread to avoid null pointer
    private Runnable mAudioReleaseRunnable = new Runnable() {
        @Override
        public void run() {
            if (!mConnectedThread.getIsReleased()) {
                mConnectedThread.release();
                mConnectedThread = null;
                mSocket = null;
                mTaskHandler.removeCallbacks(mAudioReleaseRunnable);
            } else {
                mTaskHandler.postDelayed(mAudioReleaseRunnable, mWaitInterval);
            }
        }
    };

    //The BroadcastReceiver that listens for bluetooth broadcasts
    private final BroadcastReceiver mBluetoothStateReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();
            if (action != null) {
                switch(action) {

                    case BluetoothDevice.ACTION_ACL_CONNECTED:
                        // Only react to changes concerning the device in use
                        BluetoothDevice bt1 = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
                        if (bt1.equals(mBluetoothDevice)) {
                            startRecording();
                        }
                        break;

                    case BluetoothDevice.ACTION_ACL_DISCONNECTED:
                        // Only react to changes concerning the device in use
                        BluetoothDevice bt2 = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
                        if (bt2.equals(mBluetoothDevice)) {
                            stopRecording();
                            mBluetoothDevice = null;
                            mTaskHandler.postDelayed(mSetInterfaceRunnable, mWaitInterval);
                        }
                        break;
                }
            }
        }
    };

    // This Runnable scans for available audio devices and acts if an RFCOMM device is present
    private Runnable mFindDeviceRunnable = new Runnable() {
        @Override
        public void run() {

            if (mIsBound && mBluetoothDevice == null) {

                Set<BluetoothDevice> pairedDevices = mBluetoothAdapter.getBondedDevices();
                for (BluetoothDevice bt : pairedDevices) {

                    if (bt.getBluetoothClass().getDeviceClass() == BluetoothClass.Device.AUDIO_VIDEO_WEARABLE_HEADSET) {

                        mBluetoothDevice = mBluetoothAdapter.getRemoteDevice(bt.getAddress());
                        if (mSocket != null) {
                            try {
                                mSocket.close();
                            } catch (Exception e) {
                                Log.e(LOG, "Unable to close Socket: " + e.toString());
                            }
                        }
                        mSocket = null;

                        try {
                            Class<?> clazz = mBluetoothAdapter.getRemoteDevice(bt.getAddress()).getClass();
                            Class<?>[] paramTypes = new Class<?>[]{Integer.TYPE};

                            Method m = clazz.getMethod("createRfcommSocket", paramTypes);
                            Object[] params = new Object[]{Integer.valueOf(1)};

                            mSocket = (BluetoothSocket) m.invoke(mBluetoothAdapter.getRemoteDevice(bt.getAddress()), params);
                            mSocket.connect();
                        } catch (Exception e) {
                            Log.e(LOG, "Unable to create/connect Socket: " + e.toString());
                        }

                        if (mConnectedThread != null) {
                            mConnectedThread.cancel();
                            mConnectedThread = null;
                        }
                    }

                    mConnectedThread = new ConnectedThread(mContext, mSocket, mChunklengthInS, mIsWave);
                    mConnectedThread.setPriority(Thread.MAX_PRIORITY);
                }



            } else {
                Log.e(LOG, "Client not yet bound. Retrying soon.");
            }

        }
    };

    // This Runnable has the purpose of delaying/waiting until the application is ready again
    private Runnable mSetInterfaceRunnable = new Runnable() {
        @Override
        public void run() {

                setInterface();
                mTaskHandler.removeCallbacks(mSetInterfaceRunnable);

        }
    };

    public InputProfile_RFCOMM(MainActivity context, Messenger messenger) {
        this.mContext = context;
        this.mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        this.mActivityMessenger = messenger;
    }

    @Override
    public String getInputProfile() {
        return this.INPUT_PROFILE;
    }

    @Override
    public void setInterface() {

        mKeepOpen = false;

        Log.e(LOG, "Requested setInterface()");

        if (mBluetoothAdapter == null) {
            mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        }

        // Register broadcasts receiver for bluetooth state change
        IntentFilter filterBT = new IntentFilter();
        filterBT.addAction(BluetoothDevice.ACTION_ACL_CONNECTED);
        filterBT.addAction(BluetoothDevice.ACTION_ACL_DISCONNECT_REQUESTED);
        filterBT.addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED);
        mContext.registerReceiver(mBluetoothStateReceiver, filterBT);

        if (!mBluetoothAdapter.isEnabled()) {
            mBluetoothAdapter.enable();
        }

        mBluetoothDevice = null;

        mBluetoothAdapter.cancelDiscovery();


        Log.e(LOG, "Setting interface");
        //SharedPreferences sharedPreferences = PreferenceManager.getDefaultSharedPreferences(this.mContext);
        //mChunklengthInS = Integer.parseInt(sharedPreferences.getString("chunklengthInS", "60"));
        //mIsWave = sharedPreferences.getBoolean("isWave", true);

        mTaskHandler.postDelayed(mFindDeviceRunnable, mWaitInterval);

    }

    @Override
    public void cleanUp() {

        Log.e(LOG, "Cleaning up.");

        mTaskHandler.removeCallbacks(mFindDeviceRunnable);
        mTaskHandler.removeCallbacks(mSetInterfaceRunnable);

        if (!mKeepOpen) {
            try {
                mContext.unregisterReceiver(mBluetoothStateReceiver);
            } catch (IllegalArgumentException e) {
                Log.e(LOG, "Receiver not registered: mBluetoothStateReceiver");
            }
        }
        try {
            mContext.unregisterReceiver(mUUIDReceiver);
        } catch (IllegalArgumentException e) {
            Log.e(LOG, "Receiver not registered: mUUIDReceiver");
        }
        stopRecording();
        mBluetoothAdapter = null;
        System.gc();
    }

    @Override
    public boolean getIsAudioRecorderClosed() {
        if (mConnectedThread != null) {
            return mConnectedThread.getIsReleased();
        }
        return true;
    }

    @Override
    public void registerClient() {
        Log.e(LOG, "Client Registered");
        mIsBound = true;
    }

    @Override
    public void unregisterClient() {
        Log.e(LOG, "Client Unregistered");
        mIsBound = false;
        cleanUp();
    }

    @Override
    public void batteryCritical() {
        cleanUp();
    }

    @Override
    public void chargingOff() {
        Log.e(LOG, "CharginOff");
        mBluetoothDevice = null;
        mTaskHandler.postDelayed(mSetInterfaceRunnable, mWaitInterval);
    }

    @Override
    public void chargingOn() {
        Log.e(LOG, "CharginOn");
        stopRecording();
    }

    @Override
    public void chargingOnPre() {
        Log.e(LOG, "CharginOnPre");
    }

    @Override
    public void onDestroy() {
        cleanUp();
    }


    @Override
    public void applicationShutdown() {

    }

    private void startRecording() {

        Log.e(LOG, "Requested start recording");

        if (mContext.getState() != MainActivity.state.MEASURING && mConnectedThread != null) {
            Log.d(LOG, "Start caching audio");
            //mContext.getVibration().singleBurst();
            mConnectedThread.start();
        }
    }

    public void stopRecording() {

        Log.e(LOG, "Requested stop recording");

        if (mContext.getState() == MainActivity.state.MEASURING) {
            Log.e(LOG, "Requesting stop caching audio");

            if (mConnectedThread != null) {
                mConnectedThread.stopRecording();
                mConnectedThread.cancel();
                //mContext.getVibration().singleBurst();
                //mTaskHandler.postDelayed(mAudioReleaseRunnable, mReleaseInterval);
            }
        }
    }


}
