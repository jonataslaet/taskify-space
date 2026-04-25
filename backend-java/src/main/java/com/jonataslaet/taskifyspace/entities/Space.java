package com.jonataslaet.taskifyspace.entities;

import jakarta.persistence.*;

import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "spaces")
public class Space {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    private Boolean active;

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

    public void setName(String name) { this.name = name; }

    public Boolean getActive() {
        return active;
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

    public Set<TaskExecution> getTaskExecutions() {
        return taskExecutions;
    }

    public void setTaskExecutions(Set<TaskExecution> taskExecutions) {
        this.taskExecutions = taskExecutions;
    }
}
