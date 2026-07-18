package com.jonataslaet.taskifyspace.configurations;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class SecurityConfigurationTests {

    @Test
    void passwordRecoveryEndpointsArePublicPostRoutes() {
        assertThat(SecurityConfiguration.POST_PUBLIC)
            .contains("/auth/recovery-token", "/auth/new-password/*");
    }
}
