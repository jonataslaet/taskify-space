package com.jonataslaet.taskifyspace.entities;

import jakarta.persistence.*;

import java.time.LocalDate;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String password;

    private LocalDate birthDate;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    private Set<SpaceMembership> memberships = new HashSet<>();

    @ManyToMany(mappedBy = "executors")
    private Set<SpaceTask> assignedTasks = new HashSet<>();

    protected User() {}

    public User(String name, String email, String password, LocalDate birthDate) {
        this.name = name;
        this.email = email;
        this.password = password;
        this.birthDate = birthDate;
    }

    public Long getId() { return id; }

    public String getName() { return name; }

    public String getEmail() { return email; }

    public String getPassword() { return password; }

    public LocalDate getBirthDate() { return birthDate; }

    public Set<SpaceMembership> getMemberships() { return memberships; }

    public Set<SpaceTask> getAssignedTasks() { return assignedTasks; }

    public void setName(String name) { this.name = name; }

    public void setEmail(String email) { this.email = email; }

    public void setPassword(String password) { this.password = password; }

    public void setBirthDate(LocalDate birthDate) { this.birthDate = birthDate; }
}
