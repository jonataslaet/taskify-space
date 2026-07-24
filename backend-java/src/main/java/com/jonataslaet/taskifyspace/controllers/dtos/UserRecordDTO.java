package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonView;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.utils.EmailUtils;
import com.jonataslaet.taskifyspace.validations.PasswordConstraint;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record UserRecordDTO(

    @JsonView({UserView.ReadUser.class})
    Long id,

    @NotBlank(groups = {UserView.CreateUser.class, UserView.UpdateUser.class}, message = "Email is mandatory")
    @Email(groups = {UserView.CreateUser.class, UserView.UpdateUser.class}, message = "Email must be in the expected format")
    @Size(max = 64, groups = {UserView.CreateUser.class, UserView.UpdateUser.class}, message = "Email must be less than 64")
    @JsonView({UserView.CreateUser.class, UserView.UpdateUser.class})
    String email,

    @NotBlank(groups = {UserView.CreateUser.class, UserView.UpdateUser.class}, message = "Firstname is mandatory")
    @Size(min = 2, max = 16, groups = {UserView.CreateUser.class, UserView.UpdateUser.class}, message = "Size must be between 2 and 16")
    @JsonView({UserView.CreateUser.class, UserView.UpdateUser.class})
    String name,

    @NotNull(groups = {UserView.CreateUser.class}, message = "Status is mandatory")
    @JsonView({UserView.CreateUser.class})
    UserStatusEnum status,

    @NotNull(groups = {UserView.CreateUser.class}, message = "Role is mandatory")
    @JsonView({UserView.CreateUser.class})
    UserRoleEnum role,

    @NotBlank(groups = {UserView.CreateUser.class, UserView.PasswordPut.class}, message = "Password is mandatory")
    @Size(min = 8, max = 32, groups = {UserView.CreateUser.class, UserView.PasswordPut.class}, message = "Size must be between 8 and 32")
    @PasswordConstraint(groups = {UserView.CreateUser.class, UserView.PasswordPut.class})
    @JsonView({UserView.CreateUser.class, UserView.PasswordPut.class})
    String password,

    @NotBlank(groups = UserView.PasswordPut.class, message = "Old Password is mandatory")
    @Size(min = 8, max = 32, groups = UserView.PasswordPut.class, message = "Size must be between 8 and 32")
    @PasswordConstraint(groups = UserView.PasswordPut.class)
    @JsonView({UserView.PasswordPut.class})
    String oldPassword) {

    public UserRecordDTO {
        email = EmailUtils.normalize(email);
    }

    public interface UserView {
        interface CreateUser {}
        interface ReadUser {}
        interface UpdateUser {}
        interface PasswordPut {}
    }

}
