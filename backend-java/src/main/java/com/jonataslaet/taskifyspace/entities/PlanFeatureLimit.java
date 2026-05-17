package com.jonataslaet.taskifyspace.entities;

import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
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

    @Enumerated(EnumType.STRING)
    private SpaceUserRoleEnum spaceUserRole;

    private Long usageLimit;

    public PlanFeatureLimit() {}

    public PlanFeatureLimit(FeatureEnum feature, SpaceUserRoleEnum spaceUserRole, Long usageLimit) {
        this.feature = feature;
        this.spaceUserRole = spaceUserRole;
        this.usageLimit = usageLimit;
    }

    public FeatureEnum getFeature() {
        return feature;
    }

    public SpaceUserRoleEnum getSpaceUserRole() {
        return spaceUserRole;
    }

    public Long getUsageLimit() {
        return usageLimit;
    }

    public void setFeature(FeatureEnum feature) {
        this.feature = feature;
    }

    public void setSpaceUserRole(SpaceUserRoleEnum spaceUserRole) {
        this.spaceUserRole = spaceUserRole;
    }

    public void setUsageLimit(Long usageLimit) {
        this.usageLimit = usageLimit;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof PlanFeatureLimit that)) return false;
        return feature == that.feature && spaceUserRole == that.spaceUserRole;
    }

    @Override
    public int hashCode() {
        return Objects.hash(feature, spaceUserRole);
    }
}
