package com.jonataslaet.taskifyspace.entities;

import com.jonataslaet.taskifyspace.entities.enums.SubscriptionProviderEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.Set;

@Entity
@Table(name = "subscriptions")
public class Subscription {

    private static final Set<SubscriptionStatusEnum> ACCESS_STATUSES =
        Set.of(SubscriptionStatusEnum.ACTIVE, SubscriptionStatusEnum.TRIALING);

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "plan_id", nullable = false)
    private Plan plan;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SubscriptionStatusEnum status = SubscriptionStatusEnum.ACTIVE;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SubscriptionProviderEnum provider = SubscriptionProviderEnum.INTERNAL;

    private Instant currentPeriodStart;

    private Instant currentPeriodEnd;

    private String externalCustomerId;

    private String externalSubscriptionId;

    private String externalPriceId;

    public Subscription() {}

    public boolean grantsAccessAt(Instant now) {
        boolean started = currentPeriodStart == null || !currentPeriodStart.isAfter(now);
        boolean notEnded = currentPeriodEnd == null || currentPeriodEnd.isAfter(now);
        return ACCESS_STATUSES.contains(status) && Boolean.TRUE.equals(plan.getActive()) && started && notEnded;
    }

    public boolean hasAccessStatus() {
        return grantsAccessStatus(status);
    }

    public static boolean grantsAccessStatus(SubscriptionStatusEnum status) {
        return ACCESS_STATUSES.contains(status);
    }

    public static Set<SubscriptionStatusEnum> accessStatuses() {
        return ACCESS_STATUSES;
    }

    public Long getId() {
        return id;
    }

    public User getUser() {
        return user;
    }

    public Plan getPlan() {
        return plan;
    }

    public SubscriptionStatusEnum getStatus() {
        return status;
    }

    public SubscriptionProviderEnum getProvider() {
        return provider;
    }

    public Instant getCurrentPeriodStart() {
        return currentPeriodStart;
    }

    public Instant getCurrentPeriodEnd() {
        return currentPeriodEnd;
    }

    public String getExternalCustomerId() {
        return externalCustomerId;
    }

    public String getExternalSubscriptionId() {
        return externalSubscriptionId;
    }

    public String getExternalPriceId() {
        return externalPriceId;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public void setUser(User user) {
        this.user = user;
    }

    public void setPlan(Plan plan) {
        this.plan = plan;
    }

    public void setStatus(SubscriptionStatusEnum status) {
        this.status = status;
    }

    public void setProvider(SubscriptionProviderEnum provider) {
        this.provider = provider;
    }

    public void setCurrentPeriodStart(Instant currentPeriodStart) {
        this.currentPeriodStart = currentPeriodStart;
    }

    public void setCurrentPeriodEnd(Instant currentPeriodEnd) {
        this.currentPeriodEnd = currentPeriodEnd;
    }

    public void setExternalCustomerId(String externalCustomerId) {
        this.externalCustomerId = externalCustomerId;
    }

    public void setExternalSubscriptionId(String externalSubscriptionId) {
        this.externalSubscriptionId = externalSubscriptionId;
    }

    public void setExternalPriceId(String externalPriceId) {
        this.externalPriceId = externalPriceId;
    }
}
