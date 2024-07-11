package com.example.connect_flutter_plugin;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Environment;

import com.ibm.eo.util.LogInternal;
import com.tl.uic.TealeafEOLifecycleObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.logging.Level;
import java.util.logging.Logger;

class FileUtil {
    static Boolean writeFilesEnabled = null;

    static void saveImage(String fileName, byte[] imageData) {
        if (!hasPermissionToWrite()) {
            return;
        }
        final File imagesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES);
        final File imageFile = new File(imagesDir, fileName);

        try {
            final FileOutputStream fos = new FileOutputStream(imageFile);

            fos.write(imageData);
            fos.flush();
            fos.close();
            ConnectFlutterPlugin.LOGGER.log(Level.INFO, "File saved: " + fileName);
        } catch (IOException io) {
            LogInternal.logException(TealeafEOLifecycleObject.getInstance().name(), io);
        }
    }

    static boolean delete(String path) {
        try {
            return new File(path).delete();
        }
        catch (Exception e) {
            return false;
        }
    }

    static byte[] readAll(final String path) {
        final File filePath = new File(path);

        byte[] bytes = new byte[0];
        try {
            final FileInputStream file = new FileInputStream(filePath);
            try {
                final int fileLength = (int) filePath.length();
                final int readSize = file.read(bytes = new byte[fileLength]);
                if (readSize != fileLength) {
                    Logger.getLogger(Logger.GLOBAL_LOGGER_NAME).log(Level.SEVERE, "Failed to read entire file");
                    throw new Exception("Unable to read entire file");
                }
            }
            catch (IOException e) { throw e; }
            file.close();
        } catch (Exception io) {
            Logger.getLogger(Logger.GLOBAL_LOGGER_NAME).log(Level.SEVERE, "Error reading byte file: " + io.getMessage());
        }
        return bytes;
    }

    static boolean hasPermissionToWrite() {
        return writeFilesEnabled != null && writeFilesEnabled;
    }

    static boolean setPermissionToWrite(Activity activity) {
        if (writeFilesEnabled != null)
            return writeFilesEnabled;

        writeFilesEnabled = false;

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            Logger.getLogger(Logger.GLOBAL_LOGGER_NAME).log(Level.INFO, "Permission to write false due to version codes.");
        }
        else {
            final int perm = activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE);

            if (perm == PackageManager.PERMISSION_GRANTED) {
                Logger.getLogger(Logger.GLOBAL_LOGGER_NAME).log(Level.INFO, "Permission to write granted!");
                writeFilesEnabled = true;
            }
            else {
                Logger.getLogger(Logger.GLOBAL_LOGGER_NAME).log(Level.INFO, "Requesting permissions...");
                activity.requestPermissions(new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, 11); // requestPermissions()
                Logger.getLogger(Logger.GLOBAL_LOGGER_NAME).log(Level.INFO, "No permissions :(");
            }
        }
        return writeFilesEnabled;
    }
}
