package com.example.connect_flutter_plugin;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

class Md5 {
    byte[] data;

    Md5(byte[] data) {
        this.data = data;
    }

    public String asString() {
        byte [] hash;
        try {
            hash = MessageDigest.getInstance("MD5").digest(data);
        }
        catch (NoSuchAlgorithmException e) {
            e.printStackTrace();
            return "";
        }
        final StringBuilder sb = new StringBuilder();
        for (byte b:hash) sb.append(String.format("%02x", b));

        return sb.toString();
    }
}
