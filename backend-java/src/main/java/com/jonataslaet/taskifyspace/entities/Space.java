package com.jonataslaet.taskifyspace.entities;

import jakarta.persistence.*;

import java.time.Instant;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "spaces")
public class Space {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    @Column(nullable = false)
    private Boolean active = Boolean.FALSE;

    private Instant createdAt;

    @ManyToOne
    @JoinColumn(name = "creator_id")
    private User creator;

    @OneToMany(mappedBy = "space", cascade = CascadeType.ALL, orphanRemoval = true)
    private Set<SpaceMembership> spaceMemberships = new HashSet<>();

    @OneToMany(mappedBy = "space")
    private Set<TaskExecution> taskExecutions = new HashSet<>();

    public Space() {}

    public Space(String name) {
        this.name = name;
    }

    public Long getId() { return id; }

    public String getName() { return name; }

    public Set<SpaceMembership> getSpaceMemberships() { return spaceMemberships; }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public User getCreator() {
        return creator;
    }

    public void setName(String name) { this.name = name; }

    public Boolean getActive() {
        return Boolean.TRUE.equals(active);
    }

    public void setActive(Boolean active) {
        this.active = active;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public void setSpaceMemberships(Set<SpaceMembership> spaceMemberships) {
        this.spaceMemberships = spaceMemberships;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public void setCreator(User creator) {
        this.creator = creator;
    }

    public Set<TaskExecution> getTaskExecutions() {
        return taskExecutions;
    }

    public void setTaskExecutions(Set<TaskExecution> taskExecutions) {
        this.taskExecutions = taskExecutions;
    }

    @PrePersist
    public void prePersist() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
