package com.jonataslaet.taskifyspace.entities;

import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.Table;

import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "plans")
public class Plan {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String code;

    @Column(nullable = false)
    private String name;

    private String description;

    @Column(nullable = false)
    private Boolean active = Boolean.TRUE;

    @ElementCollection(targetClass = FeatureEnum.class)
    @CollectionTable(name = "plan_features", joinColumns = @JoinColumn(name = "plan_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "feature", nullable = false)
    private Set<FeatureEnum> features = new HashSet<>();

    @ElementCollection
    @CollectionTable(name = "plan_feature_limits", joinColumns = @JoinColumn(name = "plan_id"))
    private Set<PlanFeatureLimit> featureLimits = new HashSet<>();

    public Plan() {}

    public Long getId() {
        return id;
    }

    public String getCode() {
        return code;
    }

    public String getName() {
        return name;
    }

    public String getDescription() {
        return description;
    }

    public Boolean getActive() {
        return active;
    }

    public Set<FeatureEnum> getFeatures() {
        return features;
    }

    public Set<PlanFeatureLimit> getFeatureLimits() {
        return featureLimits;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public void setName(String name) {
        this.name = name;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public void setActive(Boolean active) {
        this.active = active;
    }

    public void setFeatures(Set<FeatureEnum> features) {
        this.features = features;
    }

    public void setFeatureLimits(Set<PlanFeatureLimit> featureLimits) {
        this.featureLimits = featureLimits;
    }
}
