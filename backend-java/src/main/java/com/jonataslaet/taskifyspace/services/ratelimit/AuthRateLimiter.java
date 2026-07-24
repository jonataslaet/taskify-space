package com.jonataslaet.taskifyspace.services.ratelimit;

public interface AuthRateLimiter {

    void checkLogin(String ipAddress, String email, String deviceId);

    void recordLoginFailure(String ipAddress, String email, String deviceId);

    void recordLoginSuccess(String ipAddress, String email, String deviceId);

    void checkPasswordRecovery(String ipAddress, String email, String deviceId);
}
