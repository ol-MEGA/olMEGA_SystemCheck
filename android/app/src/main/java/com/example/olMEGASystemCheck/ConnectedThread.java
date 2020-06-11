package com.example.olMEGASystemCheck;

import android.bluetooth.BluetoothSocket;
import android.media.AudioFormat;
import android.os.Messenger;
import android.util.Log;

import com.example.olMEGASystemCheck.MainActivity;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Arrays;

public class ConnectedThread extends Thread {

    private static final int RECORDER_SAMPLERATE = 16000;
    private static final int RECORDER_CHANNELS = 2;
    private static final int RECORDER_AUDIO_ENCODING = AudioFormat.ENCODING_PCM_16BIT;
    private static int N_BITS = 16;
    private static int INSTANCE = 0;
    private final String LOG = "ConnectedThread";
    private BluetoothSocket mmSocket;
    private OutputStream mmOutStream;
    private BufferedInputStream bis;
    private BufferedOutputStream OutputFile;
    private boolean is32bitRecording = false;
    private int block_size = 32;
    private int numBlocks = 0;
    private int lostBlocks = 0;
    private int leftLevel = 0;
    private int rightLevel = 0;
    private boolean isRecording = false;
    private int AudioVolume = 0;
    private Messenger mMessenger;
    private boolean isWave;
    private int chunklengthInBytes = 0;
    private int chunklengthInS = 0;
    private InputStream tmpIn = null;
    private OutputStream tmpOut = null;
    private int countCorrectPackages = 0;
    private boolean isReleased;
    private MainActivity mContext;


    // Sampling Rate is fixed for now
    public ConnectedThread(MainActivity context, BluetoothSocket socket, int _chunkLengthInS,
                           boolean isWave) {

        this.chunklengthInS = _chunkLengthInS;
        this.isWave = isWave;
        this.mmSocket = socket;
        this.mContext = context;

        this.isReleased = true;
        INSTANCE += 1;

        try {
            tmpIn = mmSocket.getInputStream();
            tmpOut = mmSocket.getOutputStream();
        } catch (IOException e) {
            e.printStackTrace();
        }
        mmOutStream = tmpOut;

        try {
            bis = new BufferedInputStream(tmpIn);
        } catch (Exception e) {
            Log.e(LOG, "Unable to create Buffered Input Stream: " + e.toString());
        }

    }

    public void run() {

        isRecording = true;
        isReleased = false;
        mContext.startRecording();


        int buffer_size = block_size * 4;
        int additionalBytesCount = 6;
        int count = 0, tmpByte;
        RingBuffer ringBuffer = new RingBuffer(buffer_size + additionalBytesCount);

        numBlocks = 0;
        lostBlocks = 0;

        countCorrectPackages = 0;
        byte[] lastAudioBlock = new byte[buffer_size];

        chunklengthInBytes = (chunklengthInS * RECORDER_SAMPLERATE * RECORDER_CHANNELS * N_BITS / 8);

        byte[] buffer = new byte[buffer_size];
        int bytesToWrite = 0, bytesRemaining = 0;

        Log.e(LOG, "Recording started.");

        // recording loop
        while (isRecording) {

            AudioFileIO fileIO = new AudioFileIO();
            DataOutputStream outputStream = fileIO.openDataOutStream(
                    RECORDER_SAMPLERATE,
                    RECORDER_CHANNELS,
                    RECORDER_AUDIO_ENCODING,
                    isWave
            );

            // write remaining data from last block
            if (bytesRemaining > 0) {
                try {
                    outputStream.write(buffer, bytesToWrite, bytesRemaining);
                    bytesRemaining = 0;
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }

            // chunk loop
            int bytesWritten = 0;
            int bytesRead = 0;

            while (bytesWritten < chunklengthInBytes && isRecording && bis != null) {

                try {
                    //int bytesRead = audioRecord.read(buffer, 0, bufferSize);
                    ringBuffer.addByte((byte) bis.read());
                    count++;

                    if (ringBuffer.getByte(0) == (byte) 0x0
                            && ringBuffer.getByte(-1) == (byte) 0x80
                            && ringBuffer.getByte(-(buffer_size + 5)) == (byte) 0x7F
                            && ringBuffer.getByte(-(buffer_size + 4)) == (byte) 0xFF) {

                        count = 0;
                        lastAudioBlock = Arrays.copyOf(ringBuffer.data(-(buffer_size + 3), buffer_size), buffer_size);
                        AudioVolume = (short) (((ringBuffer.getByte(-2) & 0xFF) << 8) | (ringBuffer.getByte(-3) & 0xFF));
                        countCorrectPackages++;
                    } else if (count == buffer_size + additionalBytesCount) {
                        count = 0;
                        lostBlocks++;
                        countCorrectPackages = 0;
                    }
                    if (count == 0) { //count == 0

                        numBlocks++;
                        leftLevel = 0;
                        rightLevel = 0;
                        for (int countSample = 0; countSample < buffer_size; countSample += 2) {
                            short int16 = (short) (((lastAudioBlock[countSample + 1] & 0xFF) << 8) | (lastAudioBlock[countSample] & 0xFF));
                            if (countSample % 4 == 0)
                                leftLevel += Math.abs(int16);
                            else
                                rightLevel += Math.abs(int16);
                        }

                        if (outputStream != null) {
                            for (int countSample = 0; countSample < buffer_size; countSample += 2) {
                                short int16 = (short) (((lastAudioBlock[countSample + 1] & 0xFF) << 8) | (lastAudioBlock[countSample] & 0xFF));

                                if (is32bitRecording) {
                                    int int32 = int16 << (16 - AudioVolume);
                                    outputStream.write((byte)(int32 >> 24));
                                    outputStream.write((byte)(int32 >> 16));
                                    outputStream.write((byte)(int32 >> 8));
                                    outputStream.write((byte)(int32));

                                } else {

                                    /** Exchanged the following two lines for each other to tackle big endian/little endian problem **/
                                    outputStream.write(int16);
                                    outputStream.write(int16 >> 8);

                                    bytesWritten += 2; // 4?
                                }
                            }

                            outputStream.flush();

                            if (!isRecording) {
                                try {
                                    outputStream.close();
                                } catch (Exception e) {
                                }
                                outputStream = null;
                            }

                        } else {
                            outputStream.write(lastAudioBlock);
                        }


                    }
                } catch (Exception e) {
                    Log.e(LOG, "Error.");
                    e.printStackTrace();

                    stopRecording();
                }

            }
            stopRecording();
            fileIO.closeDataOutStream();
        }
        mContext.stopRecording();
        Log.e(LOG, "Recording stopped.");

    }

    public void stopRecording() {
        isRecording = false;
    }

    public void release() {
        try {
            mmSocket.close();
        } catch (Exception e) {
            Log.e(LOG, "Error closing socket.");
        }

        tmpIn = null;
        tmpOut = null;
        mmOutStream = null;

        isReleased = true;
        INSTANCE = 0;
        mContext.stopRecording();
    }

    public boolean getIsReleased() {
        return isReleased;
    }


    /* Call this from the main activity to send data to the remote device */
    public void write(byte[] bytes) {
        try {
            mmOutStream.write(bytes);
        } catch (IOException e) {
        }
    }

    /* Call this from the main activity to shutdown the connection */
    public void cancel() {
        try {
            isRecording = false;
            mmSocket.close();
        } catch (IOException e) {
        }
    }

    private class RingBuffer {
        private byte[] Data;
        private int idx;

        public RingBuffer(int BufferSize) {
            Data = new byte[BufferSize];
            idx = 0;
        }

        public void addByte(byte data) {
            idx = (idx + 1) % Data.length;
            Data[idx] = data;
        }

        public byte getByte(int currIdx) {
            currIdx = (idx + currIdx) % Data.length;
            if (currIdx < 0)
                currIdx += Data.length;
            return Data[currIdx];
        }

        public byte[] data(int startIdx, int length) {
            byte[] returnArray = new byte[length];
            startIdx = (idx + startIdx) % Data.length;
            if (startIdx < 0)
                startIdx += Data.length;
            int endIdx = startIdx + length;
            int tmpLen = Math.min(length, Data.length - startIdx);
            System.arraycopy(Data, startIdx, returnArray, 0, tmpLen);
            if (tmpLen != length)
                System.arraycopy(Data, 0, returnArray, tmpLen, length - tmpLen);
            return returnArray;
        }
    }


}