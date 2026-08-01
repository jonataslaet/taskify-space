package com.jonataslaet.taskifyspace.configurations;

import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;

@Testcontainers
@ActiveProfiles("production")
@SpringBootTest(properties = {
    "security.email.root=root@example.com",
    "security.email.password-recover.token.minutes=30",
    "security.email.registration-confirmation.token.minutes=5",
    "security.email.registration-confirmation.cleanup.enabled=false",
    "security.password.root=RootPass1!",
    "security.jwt.secret=test-secret"
})
class ProductionDatabaseMigrationTests {

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void datasourceProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.datasource.driver-class-name", postgres::getDriverClassName);
    }

    @Autowired
    private Flyway flyway;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private Environment environment;

    @Test
    void productionProfileAppliesFlywayMigrationsAndValidatesJpaSchema() {
        assertThat(environment.getProperty("spring.flyway.enabled", Boolean.class)).isTrue();
        assertThat(environment.getProperty("spring.jpa.hibernate.ddl-auto")).isEqualTo("validate");
        assertThat(Arrays.stream(flyway.info().applied())
            .map(migration -> migration.getVersion().toString()))
            .contains("1", "2", "3", "4", "5", "6", "7", "8", "9");
        assertThat(userRepository.existsByEmail("root@example.com")).isTrue();
    }
}
