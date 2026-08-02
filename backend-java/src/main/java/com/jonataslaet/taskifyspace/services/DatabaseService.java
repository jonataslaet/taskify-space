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
import com.jonataslaet.taskifyspace.utils.EmailUtils;
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
        String normalizedEmailRoot = EmailUtils.normalize(this.emailRoot);
        User createdAdmin = userRepository.findByEmail(normalizedEmailRoot).orElse(new User());
        if (ObjectUtils.isEmpty(createdAdmin.getEmail())) {
            createdAdmin.setRole(UserRoleEnum.ROLE_ADMIN);
            createdAdmin.setEmail(normalizedEmailRoot);
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

    private User createUserMaridoBellaLaet() {
        final String userEmail = "maridobellalaet@gmail.com";
        User createdUser = userRepository.findByEmail(userEmail).orElse(new User());
        if (ObjectUtils.isEmpty(createdUser.getEmail())) {
            createdUser.setRole(UserRoleEnum.ROLE_USER);
            createdUser.setEmail(userEmail);
            createdUser.setPassword(passwordEncoder.encode(this.passwordRoot));
            createdUser.setName("Marido Bella Laet");
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
        boolean alreadyHasAccessSubscription = subscriptionRepository.findByUserId(user.getId()).stream()
            .anyMatch(Subscription::hasAccessStatus);
        if (alreadyHasAccessSubscription) {
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

    public void initializeProductionBaseline() {
        createAdminJonatasLaet();
        createDefaultPlans();
    }

    private DefaultPlans createDefaultPlans() {
        Plan basicPlan = this.createPlan("BASIC", "Basic", "Plano basico para uso individual",
            Set.of(
                new PlanFeatureLimit(FeatureEnum.CREATE_SPACE, 1L),
                new PlanFeatureLimit(FeatureEnum.CREATE_TASK, 10L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN, 1L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER, 1L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT, 4L)
            ));

        Plan proPlan = this.createPlan("PRO", "Pro", "Plano com funcionalidades principais",
            Set.of(
                new PlanFeatureLimit(FeatureEnum.CREATE_SPACE, 3L),
                new PlanFeatureLimit(FeatureEnum.CREATE_TASK, 50L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN, 2L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER, 5L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT, 20L)
            ));

        Plan premiumPlan = this.createPlan("PREMIUM", "Premium", "Plano completo para equipes maiores",
            Set.of(
                new PlanFeatureLimit(FeatureEnum.CREATE_SPACE, 20L),
                new PlanFeatureLimit(FeatureEnum.CREATE_TASK, 250L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN, 5L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER, 10L),
                new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT, 100L)
            ));

        return new DefaultPlans(basicPlan, proPlan, premiumPlan);
    }

    private record DefaultPlans(Plan basicPlan, Plan proPlan, Plan premiumPlan) {}

    public SpaceRecordDTO getSpaceResidenciaCasalLaetDTO() {
        Space space = new Space();
        space.setActive(true);
        space.setName("Residência do Casal Laet");
        return SpaceMapper.toDTO(space);
    }

    public SpaceRecordDTO getSpaceBellaResidenceDTO() {
        Space space = new Space();
        space.setActive(true);
        space.setName("Residência do Marido da Bella");
        return SpaceMapper.toDTO(space);
    }

    private void createActiveSpace(String name, User creator) {
        Space space = new Space();
        space.setActive(true);
        space.setName(name);
        SpaceRecordDTO createdSpace = spaceService.createSpace(SpaceMapper.toDTO(space), creator);
        spaceService.toggleActiveSpace(creator, createdSpace.id());
    }

    private void createJonatasLaetSpaces(User adminJonatasLaet) {
        Set.of(
            "Casa do Jonatas",
            "Apartamento Centro",
            "Escritorio Taskify",
            "Projeto Reforma",
            "Chacara da Familia",
            "Condominio Bela Vista",
            "Loja Piloto",
            "Time Operacional",
            "Equipe Financeira",
            "Manutencao Predial",
            "Casa de Praia",
            "Laboratorio de Testes",
            "Coworking Fortaleza",
            "Residencia dos Pais",
            "Eventos da Familia"
        ).forEach(spaceName -> createActiveSpace(spaceName, adminJonatasLaet));
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

    public TaskRecordDTO getTaskRecordPagarContaAguaDTO(SpaceRecordDTO spaceRecordDTO) {
        Space space = spaceService.getSpaceEntity(spaceRecordDTO.id());
        Task task = new Task();
        task.setCategory(TaskCategoryEnum.FINANCIAL);
        task.setScore(new BigDecimal("80.0"));
        task.setDescription("Pagar conta de água");
        task.setSpace(space);
        return TaskMapper.toDTO(task);
    }

    private void activateUser(User user) {
        user.setStatus(UserStatusEnum.ACTIVE);
        userRepository.save(user);
    }

    public void initializeDemoDatabase() {
        User adminJonatasLaet = this.createAdminJonatasLaet();
        User userJoiceLaet = this.createUserJoiceLaet();
        User userRalphLaet = this.createUserRalphLaet();
        User userBellaLaet = this.createUserBellaLaet();
        User userMaridoBellaLaet = this.createUserMaridoBellaLaet();
        activateUser(userJoiceLaet);
        activateUser(userRalphLaet);
        activateUser(userBellaLaet);
        activateUser(userMaridoBellaLaet);

        DefaultPlans defaultPlans = createDefaultPlans();

        this.grantInternalSubscription(adminJonatasLaet, defaultPlans.premiumPlan());
        this.grantInternalSubscription(userJoiceLaet, defaultPlans.basicPlan());
        this.grantInternalSubscription(userBellaLaet, defaultPlans.basicPlan());

        if (spaceMembershipService.hasSpaceMembership(userJoiceLaet)) {
            return;
        }

        createJonatasLaetSpaces(adminJonatasLaet);

        SpaceRecordDTO spaceResidenciaCasalLaet = spaceService.createSpace(getSpaceResidenciaCasalLaetDTO(), userJoiceLaet);
        spaceService.toggleActiveSpace(userJoiceLaet, spaceResidenciaCasalLaet.id());

        SpaceRecordDTO spaceBella = spaceService.createSpace(getSpaceBellaResidenceDTO(), userBellaLaet);
        spaceService.toggleActiveSpace(userBellaLaet, spaceBella.id());

        TaskRecordDTO taskRecordDTO1 = taskService.createTask(userJoiceLaet, getTaskRecordTrocarBotijaoDTO(spaceResidenciaCasalLaet));
        TaskRecordDTO taskRecordDTO2 = taskService.createTask(userJoiceLaet, getTaskRecordPagarContaAguaDTO(spaceResidenciaCasalLaet));

        taskService.toggleActiveTask(userJoiceLaet, taskRecordDTO1.id());
        taskService.toggleActiveTask(userJoiceLaet, taskRecordDTO2.id());

        spaceService.requestParticipation(spaceResidenciaCasalLaet.id(), adminJonatasLaet);
        spaceService.requestParticipation(spaceResidenciaCasalLaet.id(), userRalphLaet);
        spaceService.requestParticipation(spaceResidenciaCasalLaet.id(), userBellaLaet);

        Set<Long> usersToBeApproved = new HashSet<>();
        usersToBeApproved.add(userRalphLaet.getId());
        usersToBeApproved.add(userBellaLaet.getId());
        usersToBeApproved.add(adminJonatasLaet.getId());

        spaceMembershipService.aproveSpaceMemberships(spaceResidenciaCasalLaet.id(), userJoiceLaet, usersToBeApproved);

        spaceService.requestParticipation(spaceBella.id(), userMaridoBellaLaet);
        usersToBeApproved = new HashSet<>();
        usersToBeApproved.add(userMaridoBellaLaet.getId());
        spaceMembershipService.aproveSpaceMemberships(spaceBella.id(), userBellaLaet, usersToBeApproved);
    }
}
