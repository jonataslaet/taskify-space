package com.jonataslaet.taskifyspace.entities;

import com.jonataslaet.taskifyspace.entities.enums.TaskStatusEnum;
import jakarta.persistence.*;

import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "space_tasks")
public class SpaceTask {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "space_id", nullable = false)
    private Space space;

    @ManyToOne(optional = false)
    @JoinColumn(name = "task_id", nullable = false)
    private Task task;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TaskStatusEnum status;

    @ManyToMany
    @JoinTable(
        name = "space_task_executors",
        joinColumns = @JoinColumn(name = "space_task_id"),
        inverseJoinColumns = @JoinColumn(name = "user_id")
    )
    private Set<User> executors = new HashSet<>();

    protected SpaceTask() {}

    public SpaceTask(Space space, Task task) {
        this.space = space;
        this.task = task;
    }

    public Long getId() { return id; }

    public Space getSpace() { return space; }

    public Task getTask() { return task; }

    public Set<User> getExecutors() { return executors; }

    public void setSpace(Space space) { this.space = space; }

    public void setTask(Task task) { this.task = task; }

    public TaskStatusEnum getStatus() {
        return status;
    }

    public void setStatus(TaskStatusEnum status) {
        this.status = status;
    }

    public void setId(Long id) {
        this.id = id;
    }
}
