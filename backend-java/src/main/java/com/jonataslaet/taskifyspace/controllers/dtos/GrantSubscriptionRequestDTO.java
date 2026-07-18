package com.jonataslaet.taskifyspace.controllers.dtos;

import com.jonataslaet.taskifyspace.entities.enums.SubscriptionProviderEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;

import java.time.Instant;

public record GrantSubscriptionRequestDTO(
    SubscriptionStatusEnum status,
    SubscriptionProviderEnum provider,
    Instant currentPeriodStart,
    Instant currentPeriodEnd,
    String externalCustomerId,
    String externalSubscriptionId,
    String externalPriceId
) {}
