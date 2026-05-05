package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.Task;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.mappers.SpaceMapper;
import com.jonataslaet.taskifyspace.mappers.TaskMapper;
import com.jonataslaet.taskifyspace.repositories.SpaceRepository;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.ObjectUtils;

import java.math.BigDecimal;
import java.util.HashSet;
import java.util.Objects;
import java.util.Set;

@Service
@Transactional
public class DatabaseService {

    @Value("${security.email.root}")
    private String emailRoot;

    @Value("${security.password.root}")
    private String passwordRoot;

    private final PasswordEncoder passwordEncoder;
    private final UserRepository userRepository;
    private final SpaceService spaceService;
    private final TaskService taskService;
    private final SpaceMembershipService spaceMembershipService;

    public DatabaseService(PasswordEncoder passwordEncoder, UserRepository userRepository, SpaceService spaceService,
                           TaskService taskService, SpaceMembershipService spaceMembershipService) {
        this.passwordEncoder = passwordEncoder;
        this.userRepository = userRepository;
        this.spaceService = spaceService;
        this.taskService = taskService;
        this.spaceMembershipService = spaceMembershipService;
    }

    private User createAdmin1() {
        User createdAdmin = userRepository.findByEmail(this.emailRoot).orElse(new User());
        if (ObjectUtils.isEmpty(createdAdmin.getEmail())) {
            createdAdmin.setRole(UserRoleEnum.ROLE_ADMIN);
            createdAdmin.setEmail(this.emailRoot);
            createdAdmin.setPassword(passwordEncoder.encode(this.passwordRoot));
            createdAdmin.setName("Jonatas Laet");
            createdAdmin.setStatus(UserStatusEnum.ACTIVE);
            userRepository.save(createdAdmin);
        }
        return createdAdmin;
    }

    private User createAdmin2() {
        User createdAdmin = userRepository.findByEmail("blendolaet@gmail.com").orElse(new User());
        if (ObjectUtils.isEmpty(createdAdmin.getEmail())) {
            createdAdmin.setRole(UserRoleEnum.ROLE_ADMIN);
            createdAdmin.setEmail("blendolaet@gmail.com");
            createdAdmin.setPassword(passwordEncoder.encode(this.passwordRoot));
            createdAdmin.setName("Blendo Laet");
            createdAdmin.setStatus(UserStatusEnum.ACTIVE);
            userRepository.save(createdAdmin);
        }
        return createdAdmin;
    }

    private User createUser() {
        final String userEmail = "santoslaet@gmail.com";
        User createdUser = userRepository.findByEmail(userEmail).orElse(new User());
        if (ObjectUtils.isEmpty(createdUser.getEmail())) {
            createdUser.setRole(UserRoleEnum.ROLE_USER);
            createdUser.setEmail(userEmail);
            createdUser.setPassword(passwordEncoder.encode(this.passwordRoot));
            createdUser.setName("Santos Laet");
            createdUser.setStatus(UserStatusEnum.ACTIVE);
            userRepository.save(createdUser);
        }
        return createdUser;
    }

    public SpaceRecordDTO createSpace(User user) {
        Space space = new Space();
        space.setActive(true);
        space.setName("Residência do Casal Laet");
        return spaceService.createSpace(SpaceMapper.toDTO(space), user);
    }

    public TaskRecordDTO createTask(Space space, User user) {
        Task task = new Task();
        task.setSpace(space);
        task.setCategory(TaskCategoryEnum.OPERATIONAL);
        task.setScore(new BigDecimal("90.0"));
        task.setDescription("Trocar o botijão de gás");
        return taskService.createTask(user, TaskMapper.toDTO(task));
    }

    public Boolean initializeDatabase() {
        User admin1 = this.createAdmin1();
        User admin2 = this.createAdmin2();
        User user = this.createUser();

        SpaceRecordDTO space = this.createSpace(admin1);
        spaceService.toggleActiveSpace(space.id());

        TaskRecordDTO taskRecordDTO = this.createTask(spaceService.getSpaceEntity(space.id()), admin1);
        taskService.toggleActiveTask(taskRecordDTO.id());

        spaceService.requestParticipation(space.id(), user);
        spaceService.requestParticipation(space.id(), admin1);
        spaceService.requestParticipation(space.id(), admin2);

        Set<Long> usersToBeApproved = new HashSet<>();
        usersToBeApproved.add(user.getId());
        usersToBeApproved.add(admin1.getId());
        usersToBeApproved.add(admin2.getId());
        spaceMembershipService.aproveSpaceMemberships(space.id(), admin1, usersToBeApproved);

        return true;
    }
}
