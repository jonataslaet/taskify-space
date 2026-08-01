package com.jonataslaet.taskifyspace.controllers.dtos;

import com.jonataslaet.taskifyspace.utils.EmailUtils;
import com.jonataslaet.taskifyspace.validations.PasswordConstraint;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateUserRequestDTO(

    @NotBlank(message = "Email is mandatory")
    @Email(message = "Email must be in the expected format")
    @Size(max = 64, message = "Email must be less than 64")
    String email,

    @NotBlank(message = "Firstname is mandatory")
    @Size(min = 2, max = 16, message = "Size must be between 2 and 16")
    String name,

    @NotBlank(message = "Password is mandatory")
    @Size(min = 8, max = 32, message = "Size must be between 8 and 32")
    @PasswordConstraint
    String password,

    @NotBlank(message = "Password confirmation is mandatory")
    @Size(min = 8, max = 32, message = "Size must be between 8 and 32")
    @PasswordConstraint
    String passwordConfirmation) {

    public CreateUserRequestDTO {
        email = EmailUtils.normalize(email);
    }
}
