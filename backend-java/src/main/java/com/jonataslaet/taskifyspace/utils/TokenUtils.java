package com.jonataslaet.taskifyspace.utils;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Objects;

public class TokenUtils {
    private static final HexFormat HEX = HexFormat.of();
    private static final SecureRandom RNG = new SecureRandom();
    private TokenUtils() {}

    public static String sha256(String value) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HEX.formatHex(md.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }

    public static String generateRandomToken() {
        byte[] bytes = new byte[32]; // 256 bits
        RNG.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public static String generateNumericToken(int digits) {
        if (digits <= 0 || digits > 9) {
            throw new IllegalArgumentException("digits must be between 1 and 9");
        }

        int bound = (int) Math.pow(10, digits);
        return String.format("%0" + digits + "d", RNG.nextInt(bound));
    }

    public static boolean isBearerAuthorizationHeader(String headerValue) {
        if (Objects.isNull(headerValue) || headerValue.isBlank()) {
            return false;
        }

        String[] authorizationParts = headerValue.trim().split("\\s+", 2);
        return "Bearer".equalsIgnoreCase(authorizationParts[0]);
    }
}
