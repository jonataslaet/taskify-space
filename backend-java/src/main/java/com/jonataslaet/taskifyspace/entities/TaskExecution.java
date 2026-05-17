package com.jonataslaet.taskifyspace.entities;

import jakarta.persistence.*;

import java.time.Instant;
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

    private Instant createdAt;

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

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Set<User> getExecutors() {
        return executors;
    }

    public void setTask(Task task) {
        this.task = task;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public void setExecutors(Set<User> executors) {
        this.executors = executors;
    }

    @PrePersist
    public void prePersist() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
