package com.jonataslaet.taskifyspace.configurations;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.cors.CorsConfiguration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class WebCorsConfigurationTests {

    @Test
    void startsWithNoConfiguredOriginsAndRejectsCrossOriginRequestsByDefault() {
        WebCorsConfiguration configuration = createConfiguration("");

        CorsConfiguration corsConfiguration = configuration.corsConfigurationSource()
            .getCorsConfiguration(new MockHttpServletRequest("GET", "/spaces"));

        assertThat(corsConfiguration).isNotNull();
        assertThat(corsConfiguration.getAllowCredentials()).isTrue();
        assertThat(corsConfiguration.getAllowedOrigins()).isEmpty();
        assertThat(corsConfiguration.getAllowedOriginPatterns()).isNullOrEmpty();
    }

    @Test
    void allowsOnlyExplicitOrigins() {
        WebCorsConfiguration configuration = createConfiguration(
            "http://localhost:3000, https://app.example.com ");

        CorsConfiguration corsConfiguration = configuration.corsConfigurationSource()
            .getCorsConfiguration(new MockHttpServletRequest("GET", "/spaces"));

        assertThat(corsConfiguration).isNotNull();
        assertThat(corsConfiguration.getAllowedOrigins())
            .containsExactly("http://localhost:3000", "https://app.example.com");
        assertThat(corsConfiguration.getAllowedOriginPatterns()).isNullOrEmpty();
    }

    @Test
    void allowsDeviceIdRequestHeaderForAuthenticationPreflight() {
        WebCorsConfiguration configuration = createConfiguration("http://localhost:3000");

        CorsConfiguration corsConfiguration = configuration.corsConfigurationSource()
            .getCorsConfiguration(new MockHttpServletRequest("POST", "/auth/login"));

        assertThat(corsConfiguration).isNotNull();
        assertThat(corsConfiguration.getAllowedHeaders())
            .contains(HttpHeaders.AUTHORIZATION, HttpHeaders.CONTENT_TYPE, HttpHeaders.ACCEPT, "X-Device-Id")
            .doesNotContain(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN);
    }

    @Test
    void rejectsWildcardOriginsBecauseCredentialsAreAllowed() {
        WebCorsConfiguration configuration = createConfiguration("https://*.example.com");

        assertThatThrownBy(configuration::corsConfigurationSource)
            .isInstanceOf(IllegalStateException.class)
            .hasMessage("CORS origins must be explicit when credentials are allowed");
    }

    private WebCorsConfiguration createConfiguration(String origins) {
        WebCorsConfiguration configuration = new WebCorsConfiguration();
        ReflectionTestUtils.setField(configuration, "corsOrigins", origins);
        return configuration;
    }
}
