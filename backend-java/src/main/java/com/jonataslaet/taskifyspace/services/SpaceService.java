package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SpaceMembershipRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.mappers.SpaceMapper;
import com.jonataslaet.taskifyspace.repositories.SpaceRepository;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.jspecify.annotations.NonNull;
import org.springframework.beans.BeanUtils;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class SpaceService {

    private final SpaceRepository spaceRepository;
    private final UserRepository userRepository;
    private final SpaceMembershipService spaceMembershipService;

    public SpaceService(
        SpaceRepository spaceRepository, UserRepository userRepository, SpaceMembershipService spaceMembershipService) {
        this.spaceRepository = spaceRepository;
        this.userRepository = userRepository;
        this.spaceMembershipService = spaceMembershipService;
    }

    @Transactional
    public SpaceRecordDTO createSpace(SpaceRecordDTO spaceRecordDTO, User authenticatedUser) {
        Space space = SpaceMapper.toEntity(spaceRecordDTO);
        space.setActive(Boolean.FALSE);
        spaceRepository.save(space);
        spaceMembershipService.setSpaceMembership(space, authenticatedUser, SpaceUserRoleEnum.ROLE_SPACE_ADMIN);
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
    public SpaceRecordDTO updateSpace(Long spaceId, SpaceRecordDTO spaceRecordDTO) {
        Space spaceEntity = getSpaceEntity(spaceId);
//        TODO: Implement a method to verify if they are equals, if not, then return spaceRecordDTO
        BeanUtils.copyProperties(spaceRecordDTO, spaceEntity, "id");
        return SpaceMapper.toDTO(spaceRepository.save(spaceEntity));
    }

    @Transactional
    public void deleteSpace(Long SpaceId) {
        if (!spaceRepository.existsById(SpaceId)) {
            throw new ResourceNotFoundException("Tarefa não encontrada");
        }
        spaceRepository.deleteById(SpaceId);
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
    public void addParticipant(Long spaceId, String email) {
        Space space = getSpaceEntity(spaceId);
        userRepository.findByEmail(email).ifPresent(user ->
            spaceMembershipService.setSpaceMembership(space, user, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT));
    }

    @Transactional
    public void toggleActiveSpace(Long spaceId) {
        Space spaceEntity = getSpaceEntity(spaceId);
        spaceEntity.setActive(!spaceEntity.getActive());
        spaceRepository.save(spaceEntity);
    }


    public Page<@NonNull SpaceMembershipRecordDTO> readParticipations(
        Specification<@NonNull SpaceMembership> spaceSpecification, Pageable pageable, Long spaceId, User authenticatedUser) {
        return spaceMembershipService.readParticipations(spaceSpecification, pageable, spaceId, authenticatedUser.getId());
    }

    public Page<@NonNull ParticipantDTO> readParticipants(
         Pageable pageable, Long spaceId, User authenticatedUser) {
        return spaceMembershipService.readParticipants(pageable, spaceId, authenticatedUser.getId());
    }
}
