package com.jonataslaet.taskifyspace.entities;

import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;

import java.util.Objects;

@Embeddable
public class PlanFeatureLimit {

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private FeatureEnum feature;

    private Long usageLimit;

    public PlanFeatureLimit() {}

    public PlanFeatureLimit(FeatureEnum feature, Long usageLimit) {
        this.feature = feature;
        this.usageLimit = usageLimit;
    }

    public FeatureEnum getFeature() {
        return feature;
    }

    public Long getUsageLimit() {
        return usageLimit;
    }

    public void setFeature(FeatureEnum feature) {
        this.feature = feature;
    }

    public void setUsageLimit(Long usageLimit) {
        this.usageLimit = usageLimit;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof PlanFeatureLimit that)) return false;
        return feature == that.feature;
    }

    @Override
    public int hashCode() {
        return Objects.hash(feature);
    }
}
