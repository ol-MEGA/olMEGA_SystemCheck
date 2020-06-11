package com.example.olMEGASystemCheck;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class IntentReceiver extends BroadcastReceiver {

    final String tag = "Intent Intercepter";

    @Override
    public void onReceive(Context context, Intent intent) {

        Log.e(tag, "GOT SOMETHING: " + intent.getStringExtra("sms_body"));

        try {
            String data = intent.getStringExtra("sms_body");
            Log.e(tag, data);

            switch (data) {
                case "Start":
                    context.sendBroadcast(new Intent("command").putExtra("do","Start"));
                    break;

                case "Stop":
                    context.sendBroadcast(new Intent("command").putExtra("do","Stop"));
                    break;

                case "Finished":
                    context.sendBroadcast(new Intent("command").putExtra("do","Finished"));
                    break;

                case "Reset":
                    context.sendBroadcast(new Intent("command").putExtra("do","Reset"));
                    break;

                case "StoreCalibration":
                    context.sendBroadcast(new Intent("command").putExtra("do","StoreCalibration"));
                    break;
            }
        } catch (Exception e) {
        }
    }
}