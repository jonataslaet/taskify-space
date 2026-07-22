package com.jonataslaet.taskifyspace.configurations;

import com.jonataslaet.taskifyspace.services.DatabaseService;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

@Configuration
public class InitializationConfiguration {

    private final DatabaseService databaseService;

    public InitializationConfiguration(DatabaseService databaseService) {
        this.databaseService = databaseService;
    }

    @Bean
    @Profile("production")
    public ApplicationRunner initializeProductionBaseline() {
        return args -> databaseService.initializeProductionBaseline();
    }

    @Bean
    @Profile({"development", "seed-demo"})
    public ApplicationRunner initializeDemoDatabase() {
        return args -> databaseService.initializeDemoDatabase();
    }
}
