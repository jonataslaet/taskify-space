package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.mappers.SpaceMapper;
import com.jonataslaet.taskifyspace.repositories.SpaceMembershipRepository;
import org.jspecify.annotations.NonNull;
import org.springframework.beans.BeanUtils;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class SpaceMembershipService {

    private final SpaceMembershipRepository spaceMembershipRepository;

    public SpaceMembershipService(SpaceMembershipRepository spaceMembershipRepository) {
        this.spaceMembershipRepository = spaceMembershipRepository;
    }

    @Transactional
    public void setSpaceMembership(Space space, User user, UserRoleEnum role) {
        spaceMembershipRepository.save(new SpaceMembership(user, space, role));
    }

}
