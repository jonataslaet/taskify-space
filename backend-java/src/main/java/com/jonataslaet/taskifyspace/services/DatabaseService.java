package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.entities.Plan;
import com.jonataslaet.taskifyspace.entities.PlanFeatureLimit;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.Subscription;
import com.jonataslaet.taskifyspace.entities.Task;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionProviderEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.mappers.SpaceMapper;
import com.jonataslaet.taskifyspace.mappers.TaskMapper;
import com.jonataslaet.taskifyspace.repositories.PlanRepository;
import com.jonataslaet.taskifyspace.repositories.SubscriptionRepository;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.ObjectUtils;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.HashSet;
import java.util.Objects;
import java.util.Set;

import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.*;

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
    private final PlanRepository planRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final Clock clock;

    public DatabaseService(PasswordEncoder passwordEncoder, UserRepository userRepository, SpaceService spaceService,
                           TaskService taskService, SpaceMembershipService spaceMembershipService,
                           PlanRepository planRepository, SubscriptionRepository subscriptionRepository, Clock clock) {
        this.passwordEncoder = passwordEncoder;
        this.userRepository = userRepository;
        this.spaceService = spaceService;
        this.taskService = taskService;
        this.spaceMembershipService = spaceMembershipService;
        this.planRepository = planRepository;
        this.subscriptionRepository = subscriptionRepository;
        this.clock = clock;
    }

    private User createAdminJonatasLaet() {
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

    private User createUserJoiceLaet() {
        final String userEmail = "joicelaet@gmail.com";
        User createdAdmin = userRepository.findByEmail(userEmail).orElse(new User());
        if (ObjectUtils.isEmpty(createdAdmin.getEmail())) {
            createdAdmin.setRole(UserRoleEnum.ROLE_USER);
            createdAdmin.setEmail(userEmail);
            createdAdmin.setPassword(passwordEncoder.encode(this.passwordRoot));
            createdAdmin.setName("Joice Laet");
            createdAdmin.setStatus(UserStatusEnum.PENDING_EVALUATION);
            userRepository.save(createdAdmin);
        }
        return createdAdmin;
    }

    private User createUserRalphLaet() {
        final String userEmail = "ralphlaet@gmail.com";
        User createdUser = userRepository.findByEmail(userEmail).orElse(new User());
        if (ObjectUtils.isEmpty(createdUser.getEmail())) {
            createdUser.setRole(UserRoleEnum.ROLE_USER);
            createdUser.setEmail(userEmail);
            createdUser.setPassword(passwordEncoder.encode(this.passwordRoot));
            createdUser.setName("Ralph Laet");
            createdUser.setStatus(UserStatusEnum.PENDING_EVALUATION);
            userRepository.save(createdUser);
        }
        return createdUser;
    }

    private User createUserBellaLaet() {
        final String userEmail = "bellalaet@gmail.com";
        User createdUser = userRepository.findByEmail(userEmail).orElse(new User());
        if (ObjectUtils.isEmpty(createdUser.getEmail())) {
            createdUser.setRole(UserRoleEnum.ROLE_USER);
            createdUser.setEmail(userEmail);
            createdUser.setPassword(passwordEncoder.encode(this.passwordRoot));
            createdUser.setName("Bella Laet");
            createdUser.setStatus(UserStatusEnum.PENDING_EVALUATION);
            userRepository.save(createdUser);
        }
        return createdUser;
    }

    private Plan createPlan(String code, String name, String description, Set<PlanFeatureLimit> featureLimits) {
        Plan plan = planRepository.findByCodeIgnoreCase(code).orElse(new Plan());
        if (Objects.isNull(plan.getId())) {
            plan.setCode(code);
            plan.setName(name);
            plan.setDescription(description);
            plan.setActive(true);
            plan.setFeatureLimits(featureLimits);
            planRepository.save(plan);
        }
        return plan;
    }

    private void grantInternalSubscription(User user, Plan plan) {
        Instant now = Instant.now(clock);
        boolean alreadyGranted = subscriptionRepository.findByUserIdAndPlanId(user.getId(), plan.getId()).stream()
            .anyMatch(subscription -> subscription.grantsAccessAt(now));
        if (alreadyGranted) {
            return;
        }

        Subscription subscription = new Subscription();
        subscription.setUser(user);
        subscription.setPlan(plan);
        subscription.setStatus(SubscriptionStatusEnum.ACTIVE);
        subscription.setProvider(SubscriptionProviderEnum.INTERNAL);
        subscription.setCurrentPeriodStart(Instant.now(clock));
        subscriptionRepository.save(subscription);
    }

    public SpaceRecordDTO getSpaceResidenciaCasalLaetDTO() {
        Space space = new Space();
        space.setActive(true);
        space.setName("Residência do Casal Laet");
        return SpaceMapper.toDTO(space);
    }

    public TaskRecordDTO getTaskRecordTrocarBotijaoDTO(SpaceRecordDTO spaceRecordDTO) {
        Space space = spaceService.getSpaceEntity(spaceRecordDTO.id());
        Task task = new Task();
        task.setCategory(TaskCategoryEnum.OPERATIONAL);
        task.setScore(new BigDecimal("90.0"));
        task.setDescription("Trocar o botijão de gás");
        task.setSpace(space);
        return TaskMapper.toDTO(task);
    }

    private void activateUser(User user) {
        user.setStatus(UserStatusEnum.ACTIVE);
        userRepository.save(user);
    }
    public Boolean initializeDatabase() {
        User adminJonatasLaet = this.createAdminJonatasLaet();
        User userJoiceLaet = this.createUserJoiceLaet();
        User userRalphLaet = this.createUserRalphLaet();
        User userBellaLaet = this.createUserBellaLaet();
//        activateUser(userJoiceLaet);
//        activateUser(userRalphLaet);
//        activateUser(userBellaLaet);

        Plan basicPlan = this.createPlan("BASIC", "Basic", "Plano basico para uso individual",
            Set.of(
                new PlanFeatureLimit(FeatureEnum.CREATE_SPACE, null, 1L),
                new PlanFeatureLimit(FeatureEnum.READ_SPACE, null, null),
                new PlanFeatureLimit(FeatureEnum.UPDATE_SPACE, ROLE_SPACE_ADMIN, null),
                new PlanFeatureLimit(FeatureEnum.UPDATE_SPACE, ROLE_SPACE_MANAGER, null),
                new PlanFeatureLimit(FeatureEnum.DELETE_SPACE, ROLE_SPACE_ADMIN, null),
                new PlanFeatureLimit(FeatureEnum.ACTIVE_OR_INACTIVE_SPACE, ROLE_SPACE_ADMIN, null),
                new PlanFeatureLimit(FeatureEnum.ACTIVE_OR_INACTIVE_SPACE, ROLE_SPACE_MANAGER, null),

                new PlanFeatureLimit(FeatureEnum.CREATE_TASK, ROLE_SPACE_ADMIN, 10L),
                new PlanFeatureLimit(FeatureEnum.READ_TASK, null, null),
                new PlanFeatureLimit(FeatureEnum.UPDATE_TASK, ROLE_SPACE_ADMIN, null),
                new PlanFeatureLimit(FeatureEnum.UPDATE_TASK, ROLE_SPACE_MANAGER, null),
                new PlanFeatureLimit(FeatureEnum.DELETE_TASK, ROLE_SPACE_ADMIN, null),

                new PlanFeatureLimit(FeatureEnum.FINISH_TASK, null, null),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN, null, 1L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER, null, 1L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT, null, 4L)
            ));

        Plan proPlan = this.createPlan("PRO", "Pro", "Plano com funcionalidades principais",
            Set.of(
                new PlanFeatureLimit(FeatureEnum.CREATE_SPACE, null, 2L),
                new PlanFeatureLimit(FeatureEnum.READ_SPACE, null, null),
                new PlanFeatureLimit(FeatureEnum.UPDATE_SPACE, ROLE_SPACE_ADMIN, null),
                new PlanFeatureLimit(FeatureEnum.UPDATE_SPACE, ROLE_SPACE_MANAGER, null),
                new PlanFeatureLimit(FeatureEnum.DELETE_SPACE, ROLE_SPACE_ADMIN, null),
                new PlanFeatureLimit(FeatureEnum.ACTIVE_OR_INACTIVE_SPACE, ROLE_SPACE_ADMIN, null),
                new PlanFeatureLimit(FeatureEnum.ACTIVE_OR_INACTIVE_SPACE, ROLE_SPACE_MANAGER, null),

                new PlanFeatureLimit(FeatureEnum.CREATE_TASK, ROLE_SPACE_ADMIN, 20L),
                new PlanFeatureLimit(FeatureEnum.READ_TASK, null, null),
                new PlanFeatureLimit(FeatureEnum.UPDATE_TASK, ROLE_SPACE_ADMIN, null),
                new PlanFeatureLimit(FeatureEnum.UPDATE_TASK, ROLE_SPACE_MANAGER, null),
                new PlanFeatureLimit(FeatureEnum.DELETE_TASK, ROLE_SPACE_ADMIN, null),

                new PlanFeatureLimit(FeatureEnum.FINISH_TASK, null, null),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN, null, 2L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER, null, 3L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT, null, 12L)
            ));

        Plan premiumPlan = this.createPlan("PREMIUM", "Premium", "Plano completo",
            Set.of(

                new PlanFeatureLimit(FeatureEnum.CREATE_SPACE, null, 3L),
                new PlanFeatureLimit(FeatureEnum.READ_SPACE, null, null),
                new PlanFeatureLimit(FeatureEnum.UPDATE_SPACE, ROLE_SPACE_ADMIN, null),
                new PlanFeatureLimit(FeatureEnum.DELETE_SPACE, ROLE_SPACE_ADMIN, null),
                new PlanFeatureLimit(FeatureEnum.ACTIVE_OR_INACTIVE_SPACE, ROLE_SPACE_ADMIN, null),
                new PlanFeatureLimit(FeatureEnum.ACTIVE_OR_INACTIVE_SPACE, ROLE_SPACE_MANAGER, null),

                new PlanFeatureLimit(FeatureEnum.CREATE_TASK, ROLE_SPACE_ADMIN, 30L),
                new PlanFeatureLimit(FeatureEnum.READ_TASK, null, null),
                new PlanFeatureLimit(FeatureEnum.UPDATE_TASK, ROLE_SPACE_ADMIN, null),
                new PlanFeatureLimit(FeatureEnum.UPDATE_TASK, ROLE_SPACE_MANAGER, null),
                new PlanFeatureLimit(FeatureEnum.DELETE_TASK, ROLE_SPACE_ADMIN, null),

                new PlanFeatureLimit(FeatureEnum.FINISH_TASK, null, null),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN, null, 5L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER, null, 10L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT, null, 50L)
            ));

//        userJoiceLaet.setStatus(UserStatusEnum.ACTIVE);
//        this.grantInternalSubscription(userJoiceLaet, basicPlan);
//
//        SpaceRecordDTO spaceResidenciaCasalLaet = spaceService.createSpace(getSpaceResidenciaCasalLaetDTO(), userJoiceLaet);
//
//        spaceService.toggleActiveSpace(userJoiceLaet, spaceResidenciaCasalLaet.id());
//
//        TaskRecordDTO taskRecordDTO = taskService.createTask(userJoiceLaet, getTaskRecordTrocarBotijaoDTO(spaceResidenciaCasalLaet));
//
//        taskService.toggleActiveTask(taskRecordDTO.id());
//
//        spaceService.requestParticipation(spaceResidenciaCasalLaet.id(), adminJonatasLaet);
//        spaceService.requestParticipation(spaceResidenciaCasalLaet.id(), userJoiceLaet);
//        spaceService.requestParticipation(spaceResidenciaCasalLaet.id(), userRalphLaet);
//        spaceService.requestParticipation(spaceResidenciaCasalLaet.id(), userBellaLaet);
//
//        Set<Long> usersToBeApproved = new HashSet<>();
//        usersToBeApproved.add(userJoiceLaet.getId());
//        usersToBeApproved.add(userRalphLaet.getId());
//        usersToBeApproved.add(userBellaLaet.getId());
//        usersToBeApproved.add(adminJonatasLaet.getId());
//
//        userJoiceLaet.setStatus(UserStatusEnum.ACTIVE);
//        spaceMembershipService.aproveSpaceMemberships(spaceResidenciaCasalLaet.id(), userJoiceLaet, usersToBeApproved);

        return true;
    }
}
