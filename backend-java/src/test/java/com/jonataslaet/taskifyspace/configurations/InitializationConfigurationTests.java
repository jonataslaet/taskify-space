package com.jonataslaet.taskifyspace.configurations;

import com.jonataslaet.taskifyspace.services.DatabaseService;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.Profile;

import java.lang.reflect.Method;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoMoreInteractions;

class InitializationConfigurationTests {

    @Test
    void productionRunnerInitializesOnlyProductionBaseline() throws Exception {
        DatabaseService databaseService = mock(DatabaseService.class);
        InitializationConfiguration configuration = new InitializationConfiguration(databaseService);

        configuration.initializeProductionBaseline().run(null);

        verify(databaseService).initializeProductionBaseline();
        verifyNoMoreInteractions(databaseService);
    }

    @Test
    void demoRunnerInitializesOnlyDemoDatabase() throws Exception {
        DatabaseService databaseService = mock(DatabaseService.class);
        InitializationConfiguration configuration = new InitializationConfiguration(databaseService);

        configuration.initializeDemoDatabase().run(null);

        verify(databaseService).initializeDemoDatabase();
        verifyNoMoreInteractions(databaseService);
    }

    @Test
    void runnersAreBoundToExpectedProfiles() throws Exception {
        Method productionRunner = InitializationConfiguration.class.getMethod("initializeProductionBaseline");
        Method demoRunner = InitializationConfiguration.class.getMethod("initializeDemoDatabase");

        assertThat(productionRunner.getAnnotation(Profile.class).value()).containsExactly("production");
        assertThat(demoRunner.getAnnotation(Profile.class).value()).containsExactly("development", "seed-demo");
    }
}
