package com.jonataslaet.taskifyspace.configurations;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

@Configuration
@EnableScheduling
@ConditionalOnProperty(
    prefix = "security.email.registration-confirmation.cleanup",
    name = "enabled",
    havingValue = "true")
public class SchedulingConfiguration {
}
