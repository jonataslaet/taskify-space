package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.SubscriptionRecordDTO;
import com.jonataslaet.taskifyspace.entities.Subscription;

import java.util.Objects;

public class SubscriptionMapper {

    public static SubscriptionRecordDTO toDTO(Subscription subscription) {
        if (Objects.isNull(subscription)) return null;
        return new SubscriptionRecordDTO(
            subscription.getId(),
            subscription.getUser().getId(),
            subscription.getUser().getEmail(),
            subscription.getPlan().getId(),
            subscription.getPlan().getCode(),
            subscription.getPlan().getName(),
            subscription.getStatus(),
            subscription.getProvider(),
            subscription.getCurrentPeriodStart(),
            subscription.getCurrentPeriodEnd(),
            subscription.getExternalCustomerId(),
            subscription.getExternalSubscriptionId(),
            subscription.getExternalPriceId()
        );
    }
}
