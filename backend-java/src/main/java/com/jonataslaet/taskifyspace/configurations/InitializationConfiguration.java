package com.jonataslaet.taskifyspace.configurations;

import com.jonataslaet.taskifyspace.services.DatabaseService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Profile;

@Profile("!test")
@Configuration
public class InitializationConfiguration {

    private final DatabaseService databaseService;

    public InitializationConfiguration(DatabaseService databaseService) {
        this.databaseService = databaseService;
    }

    @Bean
    @Primary
    public Boolean initializeDatabase() {
        return databaseService.initializeDatabase();
    }
}
