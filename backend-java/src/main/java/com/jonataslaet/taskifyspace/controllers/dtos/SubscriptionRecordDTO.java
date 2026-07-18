package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionProviderEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;
import jakarta.validation.constraints.Positive;

import java.time.Instant;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record SubscriptionRecordDTO(
    @Positive(message = "Id da assinatura deve ser positivo")
    Long id,
    @Positive(message = "Id do usuario deve ser positivo")
    Long userId,
    String userEmail,
    @Positive(message = "Id do plano deve ser positivo")
    Long planId,
    String planCode,
    String planName,
    SubscriptionStatusEnum status,
    SubscriptionProviderEnum provider,
    Instant currentPeriodStart,
    Instant currentPeriodEnd,
    String externalCustomerId,
    String externalSubscriptionId,
    String externalPriceId
) {}
