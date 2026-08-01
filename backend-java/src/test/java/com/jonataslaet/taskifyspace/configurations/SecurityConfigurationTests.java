package com.jonataslaet.taskifyspace.configurations;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.jonataslaet.taskifyspace.controllers.dtos.StandardErrorRecordDTO;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.BadCredentialsException;

import static org.assertj.core.api.Assertions.assertThat;

class SecurityConfigurationTests {

    @Test
    void passwordRecoveryEndpointsArePublicPostRoutes() {
        assertThat(SecurityConfiguration.POST_PUBLIC)
            .contains("/auth/recovery-token", "/auth/new-password/*");
    }

    @Test
    void registrationConfirmationEndpointIsPublicGetRoute() {
        assertThat(SecurityConfiguration.GET_PUBLIC)
            .contains("/users/confirm-registration/*");
    }

    @Test
    void authenticationEntryPointHandlesExceptionWithoutCause() throws Exception {
        ObjectMapper mapper = new ObjectMapper().findAndRegisterModules();
        SecurityConfiguration securityConfiguration = new SecurityConfiguration(null, null, mapper);
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/private");
        MockHttpServletResponse response = new MockHttpServletResponse();

        securityConfiguration.customAuthenticationEntryPoint().commence(
            request,
            response,
            new BadCredentialsException("Credenciais invalidas"));

        StandardErrorRecordDTO error = mapper.readValue(response.getContentAsString(), StandardErrorRecordDTO.class);
        assertThat(response.getStatus()).isEqualTo(HttpServletResponse.SC_UNAUTHORIZED);
        assertThat(error.getStatus()).isEqualTo(HttpServletResponse.SC_UNAUTHORIZED);
        assertThat(error.getMessage()).isEqualTo("Credenciais invalidas");
        assertThat(error.getPath()).isEqualTo("/private");
    }
}
