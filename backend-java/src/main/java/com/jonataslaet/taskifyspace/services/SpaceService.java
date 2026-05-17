package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SpaceMembershipRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.mappers.SpaceMapper;
import com.jonataslaet.taskifyspace.repositories.SpaceRepository;
import com.jonataslaet.taskifyspace.repositories.TaskExecutionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.jspecify.annotations.NonNull;
import org.springframework.beans.BeanUtils;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import static com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum.APPROVED;
import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_ADMIN;
import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_MANAGER;

@Service
@Transactional(readOnly = true)
public class SpaceService {

    private final SpaceRepository spaceRepository;
    private final UserRepository userRepository;
    private final SpaceMembershipService spaceMembershipService;
    private final FeatureAccessService featureAccessService;
    private final TaskRepository taskRepository;
    private final TaskExecutionRepository taskExecutionRepository;

    public SpaceService(
        SpaceRepository spaceRepository, UserRepository userRepository, SpaceMembershipService spaceMembershipService,
        FeatureAccessService featureAccessService, TaskRepository taskRepository, TaskExecutionRepository taskExecutionRepository) {
        this.spaceRepository = spaceRepository;
        this.userRepository = userRepository;
        this.spaceMembershipService = spaceMembershipService;
        this.featureAccessService = featureAccessService;
        this.taskRepository = taskRepository;
        this.taskExecutionRepository = taskExecutionRepository;
    }

    @Transactional
    public SpaceRecordDTO createSpace(SpaceRecordDTO spaceRecordDTO, User authenticatedUser) {
        featureAccessService.requireFeature(authenticatedUser, FeatureEnum.CREATE_SPACE);
        Space space = SpaceMapper.toEntity(spaceRecordDTO);
        space.setCreator(authenticatedUser);
        space.setActive(Boolean.FALSE);
        spaceRepository.save(space);
        spaceMembershipService.setSpaceMembership(space, authenticatedUser, ROLE_SPACE_ADMIN);
        return SpaceMapper.toDTO(space);
    }

    public SpaceRecordDTO getSpaceById(Long SpaceId) {
        Space Space = getSpaceEntity(SpaceId);
        return SpaceMapper.toDTO(Space);
    }

    public Space getSpaceEntity(Long spaceId) {
        return spaceRepository.findById(spaceId).orElseThrow(() ->
            new ResourceNotFoundException("Espaço não encontrado"));
    }

    @Transactional
    public SpaceRecordDTO updateSpace(User authenticatedUser, Long spaceId, SpaceRecordDTO spaceRecordDTO) {
        Space spaceEntity = getSpaceEntity(spaceId);
        validateActiveParticipation(authenticatedUser, spaceEntity, Set.of(ROLE_SPACE_ADMIN, ROLE_SPACE_MANAGER));
        featureAccessService.requireFeature(authenticatedUser, FeatureEnum.UPDATE_SPACE, spaceEntity);
//        TODO: Implement a method to verify if they are equals, if not, then return spaceRecordDTO
        BeanUtils.copyProperties(spaceRecordDTO, spaceEntity, "id");
        return SpaceMapper.toDTO(spaceRepository.save(spaceEntity));
    }

    @Transactional
    public void deleteSpace(User authenticatedUser, Long spaceId) {
        Space spaceEntity = getSpaceEntity(spaceId);
        validateActiveParticipation(authenticatedUser, spaceEntity, Set.of(ROLE_SPACE_ADMIN));
        featureAccessService.requireFeature(authenticatedUser, FeatureEnum.DELETE_SPACE, spaceEntity);
        taskExecutionRepository.deleteBySpaceId(spaceId);
        taskRepository.deleteBySpaceId(spaceId);
        spaceRepository.deleteById(spaceId);
    }

    public Page<@NonNull SpaceRecordDTO> findAll(
        Specification<@NonNull Space> spaceSpecification, Pageable pageable, User authenticatedUser) {
        Specification<@NonNull Space> authenticatedUserSpaces = (root, query, criteriaBuilder) -> {
            query.distinct(true);
            return criteriaBuilder.equal(
                root.join("spaceMemberships").get("user").get("id"),
                authenticatedUser.getId()
            );
        };
        return spaceRepository.findAll(
            Specification.where(authenticatedUserSpaces).and(spaceSpecification), pageable)
            .map(space -> SpaceMapper.toDTO(space, authenticatedUser));
    }

    @Transactional
    public void requestParticipation(Long spaceId, User authenticatedUser) {
        Space space = getSpaceEntity(spaceId);
        spaceMembershipService.setSpaceMembership(space, authenticatedUser, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT);
    }

    @Transactional
    public void createParticipation(User authenticatedUser, Long spaceId, String email) {
        Space spaceEntity = getSpaceEntity(spaceId);
        validateActiveParticipation(authenticatedUser, spaceEntity,
            Set.of(ROLE_SPACE_ADMIN, ROLE_SPACE_MANAGER));
        featureAccessService.requireFeature(authenticatedUser, FeatureEnum.MANAGE_PARTICIPANTS, spaceEntity);
        userRepository.findByEmail(email).ifPresent(user ->
            spaceMembershipService.setSpaceMembership(spaceEntity, user, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT));
    }

    @Transactional
    public void toggleActiveSpace(User authenticatedUser, Long spaceId) {
        Space spaceEntity = getSpaceEntity(spaceId);
        validateActiveParticipation(authenticatedUser, spaceEntity,
            Set.of(ROLE_SPACE_ADMIN, ROLE_SPACE_MANAGER));
        featureAccessService.requireFeature(authenticatedUser, FeatureEnum.ACTIVE_OR_INACTIVE_SPACE, spaceEntity);
        spaceEntity.setActive(!spaceEntity.getActive());
        spaceRepository.save(spaceEntity);
    }


    public Page<@NonNull SpaceMembershipRecordDTO> readParticipations(
        Specification<@NonNull SpaceMembership> spaceSpecification, Pageable pageable, Long spaceId, User authenticatedUser) {
        return spaceMembershipService.readParticipations(spaceSpecification, pageable, spaceId, authenticatedUser.getId());
    }

    @Transactional
    public SpaceMembershipRecordDTO updateParticipation(User authenticatedUser, Long spaceId,
        Long spaceMembershipId, SpaceMembershipStatusEnum status, SpaceUserRoleEnum spaceUserRole) {
        Space spaceEntity = getSpaceEntity(spaceId);
        featureAccessService.requireFeature(authenticatedUser, FeatureEnum.MANAGE_PARTICIPANTS, spaceEntity);

        if (Objects.nonNull(spaceUserRole)) {
            validateActiveParticipation(authenticatedUser, spaceEntity, Set.of(ROLE_SPACE_ADMIN));
        } else {
            validateActiveParticipation(authenticatedUser, spaceEntity, Set.of(ROLE_SPACE_ADMIN, ROLE_SPACE_MANAGER));
        }

        return spaceMembershipService.updateParticipation(spaceId, spaceMembershipId, status, spaceUserRole);
    }

    public Page<@NonNull ParticipantDTO> readParticipants(
         Pageable pageable, Long spaceId, User authenticatedUser) {
        return spaceMembershipService.readParticipants(pageable, spaceId, authenticatedUser.getId());
    }

    public void validateActiveParticipation(User authenticatedUser,
        Space space, Set<SpaceUserRoleEnum> spaceUserRoleEnums) {
        boolean hasAllValidConditions = false;
        for(SpaceMembership spaceMembership: space.getSpaceMemberships()) {
            boolean hasMembershipStatusApproved = spaceMembership.getSpaceMembershipStatusEnum().equals(APPROVED);
            boolean hasAllowedSpaceRole = spaceUserRoleEnums.contains(spaceMembership.getSpaceUserRole());
            boolean isAuthenticatedUser = spaceMembership.getUser().getId().equals(authenticatedUser.getId());
            if (hasMembershipStatusApproved && hasAllowedSpaceRole && isAuthenticatedUser) {
                hasAllValidConditions = true;
                break;
            }
        }
        if (!hasAllValidConditions) {
            throw new ForbiddenException(
                "Esse usuário não participa desse espaço como nenhum dos papéis a seguir: "
                    + spaceUserRoleEnums.stream().map(Enum::name).collect(Collectors.joining(", "))
            );
        }
    }

    public void validActiveSpace(Space space) {
        if (!space.getActive()) {
            throw new ForbiddenException("Esse espaço está inativo no momento");
        }
    }
}
