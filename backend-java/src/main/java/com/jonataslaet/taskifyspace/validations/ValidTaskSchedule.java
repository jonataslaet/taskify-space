package com.jonataslaet.taskifyspace.validations;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Documented
@Constraint(validatedBy = ValidTaskScheduleValidator.class)
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface ValidTaskSchedule {

    String message() default "Ao menos uma data da agenda da tarefa deve ser informada";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
