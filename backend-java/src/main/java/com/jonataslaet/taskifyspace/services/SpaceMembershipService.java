package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SpaceMembershipRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.exceptions.DuplicationException;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
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

import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;

import static com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum.BLOCKED;
import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT;

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
        boolean membershipAlreadyExists = spaceMembershipRepository
            .existsBySpaceIdAndUserIdAndSpaceUserRoleIn(space.getId(), user.getId(), Set.of(role));

        if (membershipAlreadyExists) return;

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
        return getSpaceMemberships(space, Set.of(authenticatedUser.getId()));
    }

    public Set<SpaceMembership> getSpaceMemberships(Space space, Set<Long> usersIds) {
        return spaceMembershipRepository.findBySpaceIdUsersIds(space.getId(), usersIds);
    }

    @Transactional
    public SpaceMembershipRecordDTO updateParticipation(
        Long spaceId, Long spaceMembershipId, SpaceMembershipStatusEnum status, SpaceUserRoleEnum spaceUserRole) {

        SpaceMembership spaceMembership = spaceMembershipRepository.findByIdAndSpaceId(spaceMembershipId, spaceId)
            .orElseThrow(() -> new ResourceNotFoundException("Participação não encontrada"));

        if (Objects.isNull(status) && Objects.isNull(spaceUserRole)) {
            return SpaceMembershipMapper.toDTO(spaceMembership);
        }

        SpaceUserRoleEnum targetSpaceUserRole = Objects.nonNull(spaceUserRole)
            ? spaceUserRole
            : spaceMembership.getSpaceUserRole();
        validNotDuplicateParticipation(spaceMembership, targetSpaceUserRole);

        spaceMembership.setSpaceMembershipStatusEnum(status);
        if (Objects.nonNull(spaceUserRole)) spaceMembership.setSpaceUserRole(targetSpaceUserRole);

        return SpaceMembershipMapper.toDTO(spaceMembershipRepository.save(spaceMembership));
    }

    private void validNotDuplicateParticipation(
        SpaceMembership spaceMembership, SpaceUserRoleEnum targetSpaceUserRole) {
        boolean isDuplicated = spaceMembershipRepository.existsBySpaceIdAndUserIdAndSpaceUserRoleInAndIdNot(
            spaceMembership.getSpace().getId(), spaceMembership.getUser().getId(), Set.of(targetSpaceUserRole),
            spaceMembership.getId());
        if (isDuplicated) {
            throw new DuplicationException("Já existe uma participação exatamente assim neste espaço");
        }
    }

    public Set<User> getParticipantsBySpaceAndUsersIds(Space space, Set<Long> usersIds) {
        return spaceMembershipRepository.findParticipantsByIds(
            space.getId(), usersIds, ROLE_SPACE_PARTICIPANT);
    }

    @Transactional
    public void blockOwnParticipation(Space space, User authenticatedUser) {
        Set<SpaceMembership> existingMemberships =
            spaceMembershipRepository.findBySpaceIdAndUserId(space.getId(), authenticatedUser.getId());

        List<SpaceMembership> blockedMemberships = Arrays.stream(SpaceUserRoleEnum.values())
            .map(role -> getOrCreateBlockedMembership(existingMemberships, space, authenticatedUser, role))
            .toList();

        spaceMembershipRepository.saveAll(blockedMemberships);
    }

    private SpaceMembership getOrCreateBlockedMembership(
        Set<SpaceMembership> existingMemberships, Space space, User authenticatedUser, SpaceUserRoleEnum role) {
        SpaceMembership spaceMembership = existingMemberships.stream()
            .filter(existingMembership -> existingMembership.getSpaceUserRole().equals(role))
            .findFirst()
            .orElseGet(() -> new SpaceMembership(authenticatedUser, space, role));

        spaceMembership.setSpaceMembershipStatusEnum(BLOCKED);
        return spaceMembership;
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
