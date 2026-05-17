package com.jonataslaet.taskifyspace.entities;

import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import jakarta.persistence.*;

@Entity
@Table(
    name = "space_memberships",
    uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "space_id", "space_user_role"})
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
    private SpaceUserRoleEnum spaceUserRole;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SpaceMembershipStatusEnum spaceMembershipStatusEnum;

    public SpaceMembership() {}

    public SpaceMembership(User user, Space space, SpaceUserRoleEnum role) {
        this.user = user;
        this.space = space;
        this.spaceUserRole = role;
    }

    public Long getId() { return id; }

    public User getUser() { return user; }

    public Space getSpace() { return space; }

    public SpaceUserRoleEnum getSpaceUserRole() { return spaceUserRole; }

    public void setSpaceUserRole(SpaceUserRoleEnum spaceUserRole) { this.spaceUserRole = spaceUserRole; }

    public SpaceMembershipStatusEnum getSpaceMembershipStatusEnum() {
        return spaceMembershipStatusEnum;
    }

    public void setSpaceMembershipStatusEnum(SpaceMembershipStatusEnum spaceMembershipStatusEnum) {
        this.spaceMembershipStatusEnum = spaceMembershipStatusEnum;
    }
}
