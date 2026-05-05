package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SpaceMembershipRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.mappers.SpaceMembershipMapper;
import com.jonataslaet.taskifyspace.repositories.ParticipantRepository;
import com.jonataslaet.taskifyspace.repositories.SpaceMembershipRepository;
import com.jonataslaet.taskifyspace.specifications.SpaceMembershipSpecification;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;

@Service
@Transactional(readOnly = true)
public class SpaceMembershipService {

    private final SpaceMembershipRepository spaceMembershipRepository;
    private final ParticipantRepository participantRepository;

    public SpaceMembershipService(
        SpaceMembershipRepository spaceMembershipRepository,
        ParticipantRepository participantRepository) {
        this.spaceMembershipRepository = spaceMembershipRepository;
        this.participantRepository = participantRepository;
    }

    @Transactional
    public void setSpaceMembership(Space space, User user, SpaceUserRoleEnum role) {
        SpaceMembership spaceMembership = new SpaceMembership(user, space, role);
        if (role.equals(SpaceUserRoleEnum.ROLE_SPACE_ADMIN))
            spaceMembership.setSpaceMembershipStatusEnum(SpaceMembershipStatusEnum.APPROVED);
        else
            spaceMembership.setSpaceMembershipStatusEnum(SpaceMembershipStatusEnum.PENDING);
        space.getSpaceMemberships().add(spaceMembership);
        spaceMembershipRepository.save(spaceMembership);
    }

    @Transactional
    public void aproveSpaceMemberships(Long spaceId, User authenticatedUser, Set<Long> usersIds) {
        Set<SpaceMembership> spaceMemberships = spaceMembershipRepository.findBySpaceIdUsersIds(spaceId, null);
        AtomicBoolean hasAuthenticatedUserAsAdmin = new AtomicBoolean(false);

        spaceMemberships.forEach(sm -> {
            if (!hasAuthenticatedUserAsAdmin.get() && sm.getSpaceUserRole().equals(
                SpaceUserRoleEnum.ROLE_SPACE_ADMIN) && sm.getUser().getId().equals(
                authenticatedUser.getId())) {
                hasAuthenticatedUserAsAdmin.set(true);
            }
            if (usersIds.contains(sm.getUser().getId()) && !sm.getSpaceMembershipStatusEnum().equals(SpaceMembershipStatusEnum.APPROVED)) {
                sm.setSpaceMembershipStatusEnum(SpaceMembershipStatusEnum.APPROVED);
            }
        });
        if (!hasAuthenticatedUserAsAdmin.get()) {
            throw new ForbiddenException("Esse espaço não possui o usuário logado como administrador");
        }
        spaceMembershipRepository.saveAll(spaceMemberships);
    }

    public Set<SpaceMembership> getSpaceMemberships(User authenticatedUser, Space space) {
        return spaceMembershipRepository.findBySpaceIdUsersIds(space.getId(), Set.of(authenticatedUser.getId()));
    }

    public Set<User> getParticipantsBySpaceAndUsersIds(Space space, Set<Long> usersIds) {
        return spaceMembershipRepository.findParticipantsByIds(
            space.getId(), usersIds, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT);
    }

    public Page<@NonNull SpaceMembershipRecordDTO> readParticipations(
        Specification<@NonNull SpaceMembership> spaceSpecification, Pageable pageable, Long spaceId, Long authUserId) {

        boolean hasPermission =
            spaceMembershipRepository
                .existsBySpaceIdAndUserIdAndSpaceUserRoleIn(
                    spaceId,
                    authUserId,
                    Set.of(
                        SpaceUserRoleEnum.ROLE_SPACE_ADMIN,
                        SpaceUserRoleEnum.ROLE_SPACE_MANAGER
                    )
                );

        if (!hasPermission) {
            throw new ForbiddenException("Usuário não possui permissão para visualizar as participações desse espaço");
        }

        Specification<@NonNull SpaceMembership> finalSpec =
            Specification.where(SpaceMembershipSpecification.spaceId(spaceId)).and(spaceSpecification);

        return spaceMembershipRepository.findAll(finalSpec, pageable).map(SpaceMembershipMapper::toDTO);
    }

    public Page<@NonNull ParticipantDTO> readParticipants(Pageable pageable, Long spaceId, Long authUserId) {

        boolean currentUserParticipatesInThisSpaceAsParticipant =
            spaceMembershipRepository
                .existsBySpaceIdAndUserIdAndSpaceUserRoleInAndSpaceMembershipStatusEnum(
                    spaceId,
                    authUserId,
                    Set.of(SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT),
                    SpaceMembershipStatusEnum.APPROVED);

        if (!currentUserParticipatesInThisSpaceAsParticipant) {
            throw new ForbiddenException("Usuário não possui permissão para visualizar os participantes desse espaço");
        }

        return participantRepository.findParticipantsWithScores(spaceId, pageable);
    }
}
