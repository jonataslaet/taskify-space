package com.jonataslaet.taskifyspace.configurations;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

class ProfileConfigurationTests {

    @Test
    void defaultProfileIsProduction() throws IOException {
        String applicationYaml = readResource("application.yaml");

        assertThat(applicationYaml).contains("active: ${APP_PROFILE:production}");
    }

    @Test
    void productionProfileDoesNotCreateOrDropSchema() throws IOException {
        String productionYaml = readResource("application-production.yaml");

        assertThat(productionYaml).contains("ddl-auto: validate");
        assertThat(productionYaml).doesNotContain("create-drop");
    }

    @Test
    void developmentProfileKeepsCreateDropSchema() throws IOException {
        String developmentYaml = readResource("application-development.yaml");

        assertThat(developmentYaml).contains("on-profile: development");
        assertThat(developmentYaml).contains("ddl-auto: create-drop");
    }

    private String readResource(String resourceName) throws IOException {
        try (var inputStream = getClass().getClassLoader().getResourceAsStream(resourceName)) {
            assertThat(inputStream).as("Resource " + resourceName).isNotNull();
            return new String(inputStream.readAllBytes(), StandardCharsets.UTF_8);
        }
    }
}
