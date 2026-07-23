package com.jonataslaet.taskifyspace.configurations;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;

class ProfileConfigurationTests {

    private static final List<String> MOJIBAKE_SEQUENCES = List.of(
        "\uFFFD",
        "\u00C3\u00A1",
        "\u00C3\u00A3",
        "\u00C3\u00A7",
        "\u00C3\u00A9",
        "\u00C3\u00AA",
        "\u00C3\u00AD",
        "\u00C3\u00B3",
        "\u00C3\u00BA",
        "\u00C2\u00A0",
        "\u00E2\u20AC"
    );

    @Test
    void defaultProfileIsProduction() throws IOException {
        String applicationYaml = readResource("application.yaml");

        assertThat(applicationYaml).contains("active: ${APP_PROFILE:production}");
    }

    @Test
    void jwtSecretMustNotHaveDefaultValue() throws IOException {
        String applicationYaml = readResource("application.yaml");

        assertThat(applicationYaml).contains("secret: ${JWT_SECRET}");
        assertThat(applicationYaml).doesNotContain("seu-secret-jwt");
        assertThat(applicationYaml).doesNotContain("JWT_SECRET:");
    }

    @Test
    void baseConfigurationForcesUtf8LoggingCharset() throws IOException {
        String applicationYaml = readResource("application.yaml");

        assertThat(applicationYaml).contains("console: UTF-8");
        assertThat(applicationYaml).contains("file: UTF-8");
    }

    @Test
    void mavenBuildUsesUtf8Encoding() throws IOException {
        String pomXml = Files.readString(Path.of("pom.xml"), StandardCharsets.UTF_8);

        assertThat(pomXml).contains("<project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>");
        assertThat(pomXml).contains("<project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>");
    }

    @Test
    void sourceFilesDoNotContainMojibakeSequences() throws IOException {
        List<Path> filesWithMojibake;
        try (Stream<Path> paths = Files.walk(Path.of("src"))) {
            filesWithMojibake = paths
                .filter(Files::isRegularFile)
                .filter(path -> hasSupportedTextExtension(path.getFileName().toString()))
                .filter(this::containsMojibake)
                .toList();
        }

        assertThat(filesWithMojibake).isEmpty();
    }

    @Test
    void productionProfileDoesNotCreateOrDropSchema() throws IOException {
        String productionYaml = readResource("application-production.yaml");

        assertThat(productionYaml).contains("ddl-auto: validate");
        assertThat(productionYaml).doesNotContain("create-drop");
    }

    @Test
    void productionProfileDisablesSqlAndBindLogging() throws IOException {
        String productionYaml = readResource("application-production.yaml");

        assertThat(productionYaml).contains("show-sql: false");
        assertThat(productionYaml).contains("org.hibernate.SQL: OFF");
        assertThat(productionYaml).contains("org.hibernate.orm.jdbc.bind: OFF");
        assertThat(productionYaml).contains("org.hibernate.type.descriptor.sql.BasicBinder: OFF");
    }

    @Test
    void developmentProfileKeepsCreateDropSchema() throws IOException {
        String developmentYaml = readResource("application-development.yaml");

        assertThat(developmentYaml).contains("on-profile: development");
        assertThat(developmentYaml).contains("ddl-auto: create-drop");
    }

    private String readResource(String resourceName) throws IOException {
        return Files.readString(Path.of("src/main/resources", resourceName), StandardCharsets.UTF_8);
    }

    private boolean hasSupportedTextExtension(String fileName) {
        return fileName.endsWith(".java")
            || fileName.endsWith(".yaml")
            || fileName.endsWith(".yml")
            || fileName.endsWith(".properties")
            || fileName.endsWith(".xml");
    }

    private boolean containsMojibake(Path path) {
        try {
            String content = Files.readString(path, StandardCharsets.UTF_8);
            return MOJIBAKE_SEQUENCES.stream().anyMatch(content::contains);
        } catch (IOException ex) {
            throw new IllegalStateException("Could not read " + path, ex);
        }
    }
}
