package com.example.olMEGASystemCheck;

public interface InputProfile {

    void setInterface();

    String getInputProfile();

    void cleanUp();

    boolean getIsAudioRecorderClosed();

    void registerClient();

    void unregisterClient();

    void applicationShutdown();

    void batteryCritical();

    void chargingOff();

    void chargingOn();

    void chargingOnPre();

    void onDestroy();

}
