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

    @OneToMany(mappedBy = "space", cascade = CascadeType.ALL, orphanRemoval = true)
    private Set<SpaceTask> spaceTasks = new HashSet<>();

    public Space() {}

    public Space(String name) {
        this.name = name;
    }

    public Long getId() { return id; }

    public String getName() { return name; }

    public Set<SpaceMembership> getSpaceMemberships() { return spaceMemberships; }

    public Set<SpaceTask> getSpaceTasks() { return spaceTasks; }

    public void setName(String name) { this.name = name; }

    public Boolean getActive() {
        return active;
    }

    public void setActive(Boolean active) {
        this.active = active;
    }
}
