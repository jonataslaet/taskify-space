package com.jonataslaet.taskifyspace.configurations;

import org.jspecify.annotations.NonNull;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.Arrays;
import java.util.List;

@Configuration
public class WebCorsConfiguration {

    private static final String DEVICE_ID_HEADER = "X-Device-Id";

    @Value("${cors.origins:}")
    private String corsOrigins;

    @Bean
    CorsConfigurationSource corsConfigurationSource() {

        List<String> origins = parseAllowedOrigins();

        CorsConfiguration corsConfig = new CorsConfiguration();
        corsConfig.setAllowedOrigins(origins);
        corsConfig.setAllowedMethods(Arrays.asList(
            HttpMethod.POST.name(), HttpMethod.GET.name(), HttpMethod.PUT.name(),
            HttpMethod.DELETE.name(), HttpMethod.PATCH.name(), HttpMethod.OPTIONS.name()
        ));
        corsConfig.setAllowCredentials(true);
        corsConfig.setAllowedHeaders(Arrays.asList(
            HttpHeaders.AUTHORIZATION, HttpHeaders.CONTENT_TYPE, HttpHeaders.ACCEPT,
            DEVICE_ID_HEADER
        ));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", corsConfig);
        return source;
    }

    @Bean
    FilterRegistrationBean<@NonNull CorsFilter> corsFilter() {
        FilterRegistrationBean<@NonNull CorsFilter> bean = new FilterRegistrationBean<>(
            new CorsFilter(corsConfigurationSource()));
        bean.setOrder(Ordered.HIGHEST_PRECEDENCE);
        return bean;
    }

    private List<String> parseAllowedOrigins() {
        return Arrays.stream(corsOrigins.split(","))
            .map(String::trim)
            .filter(origin -> !origin.isBlank())
            .peek(this::validateExactOrigin)
            .toList();
    }

    private void validateExactOrigin(String origin) {
        if (origin.contains("*")) {
            throw new IllegalStateException("CORS origins must be explicit when credentials are allowed");
        }
    }
}
