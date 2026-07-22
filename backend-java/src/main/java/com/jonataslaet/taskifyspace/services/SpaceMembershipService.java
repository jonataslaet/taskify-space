package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SpaceMembershipRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;
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
    private final FeatureAccessService featureAccessService;

    public SpaceMembershipService(
        SpaceMembershipRepository spaceMembershipRepository,
        ParticipantRepository participantRepository,
        FeatureAccessService featureAccessService) {
        this.spaceMembershipRepository = spaceMembershipRepository;
        this.participantRepository = participantRepository;
        this.featureAccessService = featureAccessService;
    }

    @Transactional
    public void setSpaceMembership(Space space, User user, SpaceUserRoleEnum role) {
        boolean userAlreadyParticipatesInSpace = spaceMembershipRepository
            .existsBySpaceIdAndUserId(space.getId(), user.getId());
        if (userAlreadyParticipatesInSpace) {
            return;
        }

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

        spaceMemberships.stream().filter(sm -> sm.getUser().isEnabled()).forEach(sm -> {
            if (!hasAuthenticatedUserAsAdmin.get() && sm.getSpaceUserRole().equals(
                SpaceUserRoleEnum.ROLE_SPACE_ADMIN) && sm.getUser().getId().equals(
                authenticatedUser.getId())) {
                hasAuthenticatedUserAsAdmin.set(true);
            }
            if (usersIds.contains(sm.getUser().getId()) && !sm.getSpaceMembershipStatusEnum().equals(SpaceMembershipStatusEnum.APPROVED)) {
                featureAccessService.requireFeature(
                    authenticatedUser, approvalFeature(sm.getSpaceUserRole()), sm.getSpace());
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

    public boolean hasSpaceMembership(User user) {
        return spaceMembershipRepository.existsByUserId(user.getId());
    }

    @Transactional
    public SpaceMembershipRecordDTO updateParticipation(
        Long spaceId, Long spaceMembershipId, SpaceMembershipStatusEnum status, SpaceUserRoleEnum spaceUserRole,
        User authenticatedUser) {

        SpaceMembership spaceMembership = spaceMembershipRepository.findByIdAndSpaceId(spaceMembershipId, spaceId)
            .orElseThrow(() -> new ResourceNotFoundException("Participação não encontrada"));

        if (Objects.isNull(status) && Objects.isNull(spaceUserRole)) {
            return SpaceMembershipMapper.toDTO(spaceMembership);
        }

        SpaceUserRoleEnum targetSpaceUserRole = Objects.nonNull(spaceUserRole)
            ? spaceUserRole
            : spaceMembership.getSpaceUserRole();
        validNotDuplicateParticipation(spaceMembership);

        if (willIncreaseApprovedRoleCount(spaceMembership, status, targetSpaceUserRole)) {
            featureAccessService.requireFeature(
                authenticatedUser, approvalFeature(targetSpaceUserRole), spaceMembership.getSpace());
        }

        if (Objects.nonNull(status)) spaceMembership.setSpaceMembershipStatusEnum(status);
        if (Objects.nonNull(spaceUserRole)) spaceMembership.setSpaceUserRole(targetSpaceUserRole);

        return SpaceMembershipMapper.toDTO(spaceMembershipRepository.save(spaceMembership));
    }

    private boolean willIncreaseApprovedRoleCount(
        SpaceMembership spaceMembership,
        SpaceMembershipStatusEnum status,
        SpaceUserRoleEnum targetSpaceUserRole) {
        SpaceMembershipStatusEnum targetStatus = Objects.nonNull(status)
            ? status
            : spaceMembership.getSpaceMembershipStatusEnum();

        return SpaceMembershipStatusEnum.APPROVED.equals(targetStatus)
            && (!SpaceMembershipStatusEnum.APPROVED.equals(spaceMembership.getSpaceMembershipStatusEnum())
                || !spaceMembership.getSpaceUserRole().equals(targetSpaceUserRole));
    }

    private FeatureEnum approvalFeature(SpaceUserRoleEnum spaceUserRole) {
        return switch (spaceUserRole) {
            case ROLE_SPACE_ADMIN -> FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN;
            case ROLE_SPACE_MANAGER -> FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER;
            case ROLE_SPACE_PARTICIPANT -> FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT;
        };
    }

    private void validNotDuplicateParticipation(SpaceMembership spaceMembership) {
        boolean isDuplicated = spaceMembershipRepository.existsBySpaceIdAndUserIdAndIdNot(
            spaceMembership.getSpace().getId(), spaceMembership.getUser().getId(), spaceMembership.getId());
        if (isDuplicated) {
            throw new DuplicationException("Já existe uma participação deste usuário neste espaço");
        }
    }

    public Set<User> getApprovedMembersBySpaceAndUsersIds(Space space, Set<Long> usersIds) {
        return spaceMembershipRepository.findApprovedUsersByIds(
            space.getId(), usersIds, SpaceMembershipStatusEnum.APPROVED);
    }

    public Page<@NonNull SpaceMembershipRecordDTO> readParticipations(
        Specification<@NonNull SpaceMembership> spaceSpecification, Pageable pageable, Long spaceId, User authUser) {

        boolean currentUserParticipatesInThisSpace =
            spaceMembershipRepository
                .existsBySpaceIdAndUserIdAndSpaceMembershipStatusEnum(
                    spaceId,
                    authUser.getId(),
                    SpaceMembershipStatusEnum.APPROVED);

        if (!currentUserParticipatesInThisSpace) {
            throw new ForbiddenException("Usuário não possui permissão para visualizar as participações desse espaço");
        }

        Specification<@NonNull SpaceMembership> finalSpec =
            Specification.where(SpaceMembershipSpecification.spaceId(spaceId)).and(spaceSpecification);

        return spaceMembershipRepository.findAll(finalSpec, pageable).map(SpaceMembershipMapper::toDTO);
    }

    public Page<@NonNull ParticipantDTO> readParticipants(
        Pageable pageable, Long spaceId, Long authUserId, String name, SpaceUserRoleEnum spaceUserRole,
        List<TaskCategoryEnum> taskCategories) {

        boolean currentUserParticipatesInThisSpace =
            spaceMembershipRepository
                .existsBySpaceIdAndUserIdAndSpaceMembershipStatusEnum(
                    spaceId,
                    authUserId,
                    SpaceMembershipStatusEnum.APPROVED);

        if (!currentUserParticipatesInThisSpace) {
            throw new ForbiddenException("Usuário não possui permissão para visualizar os participantes desse espaço");
        }

        return participantRepository.findParticipantsWithScores(
            spaceId, pageable, name, spaceUserRole, taskCategories);
    }
}
