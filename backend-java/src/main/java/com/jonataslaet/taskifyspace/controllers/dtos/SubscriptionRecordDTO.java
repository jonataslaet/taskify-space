package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionProviderEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;

import java.time.Instant;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record SubscriptionRecordDTO(
    Long id,
    Long userId,
    String userEmail,
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
