package com.jonataslaet.taskifyspace.entities;

import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import jakarta.persistence.*;

@Entity
@Table(
    name = "space_memberships",
    uniqueConstraints = {
        @UniqueConstraint(columnNames = {"user_id", "space_id"})
    }
)
public class SpaceMembership {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(optional = false)
    @JoinColumn(name = "space_id", nullable = false)
    private Space space;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private UserRoleEnum role;

    protected SpaceMembership() {}

    public SpaceMembership(User user, Space space, UserRoleEnum role) {
        this.user = user;
        this.space = space;
        this.role = role;
    }

    public Long getId() { return id; }

    public User getUser() { return user; }

    public Space getSpace() { return space; }

    public UserRoleEnum getRole() { return role; }

    public void setRole(UserRoleEnum role) { this.role = role; }
}
