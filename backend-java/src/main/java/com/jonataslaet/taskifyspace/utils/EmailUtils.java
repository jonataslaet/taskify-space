package com.jonataslaet.taskifyspace.utils;

import java.util.Locale;
import java.util.Objects;

public final class EmailUtils {

    private EmailUtils() {}

    public static String normalize(String email) {
        return Objects.isNull(email) ? null : email.trim().toLowerCase(Locale.ROOT);
    }
}
