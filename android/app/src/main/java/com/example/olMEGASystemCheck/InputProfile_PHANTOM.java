package com.example.olMEGASystemCheck;

import android.bluetooth.BluetoothAdapter;
import android.os.Messenger;

import com.example.olMEGASystemCheck.MainActivity;

public class InputProfile_PHANTOM implements InputProfile {
    private MainActivity mContext;
    private BluetoothAdapter mBluetoothAdapter;
    private Messenger mActivityMessenger;
    private String LOG = "InputProfile_PHANTOM";

    public InputProfile_PHANTOM(MainActivity context, Messenger messenger) {
        this.mContext = context;
        this.mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        this.mActivityMessenger = messenger;
    }
    @Override
    public void setInterface() {
    }

    @Override
    public String getInputProfile() {
        return "";
    }

    @Override
    public void cleanUp() {
    }

    @Override
    public boolean getIsAudioRecorderClosed() {
        return false;
    }

    @Override
    public void registerClient() {

    }

    @Override
    public void unregisterClient() {

    }

    @Override
    public void applicationShutdown() {

    }

    @Override
    public void batteryCritical() {

    }

    @Override
    public void chargingOff() {

    }

    @Override
    public void chargingOn() {

    }

    @Override
    public void chargingOnPre() {

    }

    @Override
    public void onDestroy() {

    }
}
