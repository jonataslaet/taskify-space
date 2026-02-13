package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.mappers.SpaceMapper;
import com.jonataslaet.taskifyspace.repositories.SpaceRepository;
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
    private final SpaceMembershipService spaceMembershipService;

    public SpaceService(SpaceRepository spaceRepository, SpaceMembershipService spaceMembershipService) {
        this.spaceRepository = spaceRepository;
        this.spaceMembershipService = spaceMembershipService;
    }

    @Transactional
    public SpaceRecordDTO createSpace(SpaceRecordDTO spaceRecordDTO) {
        Space space = SpaceMapper.toEntity(spaceRecordDTO);
        space.setActive(Boolean.FALSE);
        spaceRepository.save(space);
        spaceMembershipService.setSpaceMembership(space, null, UserRoleEnum.ROLE_SPACE_ADMIN);
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

    public Page<@NonNull SpaceRecordDTO> findAll(Specification<@NonNull Space> SpaceSpecification, Pageable pageable) {
        return spaceRepository.findAll(SpaceSpecification, pageable).map(SpaceMapper::toDTO);
    }
}
