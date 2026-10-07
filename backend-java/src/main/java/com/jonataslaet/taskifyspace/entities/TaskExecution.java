package com.jonataslaet.taskifyspace.entities;

import jakarta.persistence.*;

import java.time.Instant;
import java.time.temporal.TemporalAccessor;
import java.util.Set;

@Entity
@Table(name = "tasks_executions")
public class TaskExecution {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "space_id", nullable = false)
    private Space space;

    @ManyToOne(optional = false)
    @JoinColumn(name = "task_id", nullable = false)
    private Task task;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at")
    private Instant updatedAt;

    @ManyToMany
    @JoinTable(
        name = "task_execution_users",
        joinColumns = @JoinColumn(name = "task_execution_id"),
        inverseJoinColumns = @JoinColumn(name = "user_id")
    )
    private Set<User> executors;

    public TaskExecution() {
    }

    public TaskExecution(Task task, Space space, Set<User> executors) {
        this.task = task;
        this.space = space;
        this.executors = executors;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Space getSpace() {
        return space;
    }

    public void setSpace(Space space) {
        this.space = space;
    }

    public Task getTask() {
        return task;
    }

    public Set<User> getExecutors() {
        return executors;
    }

    public void setTask(Task task) {
        this.task = task;
    }

    @PrePersist
    public void prePersist() {
        createdAt = Instant.now();
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = Instant.now();
    }

    public Instant getCreatedAt() {
        return this.createdAt;
    }

    public void setCreatedAt(Instant instant) {
        this.createdAt = instant;
    }
}
