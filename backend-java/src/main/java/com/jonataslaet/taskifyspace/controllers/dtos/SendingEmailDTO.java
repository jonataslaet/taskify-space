package com.jonataslaet.taskifyspace.controllers.dtos;

public record SendingEmailDTO(
    String to,
    String[] cc,
    String subject,
    String body
) {
}