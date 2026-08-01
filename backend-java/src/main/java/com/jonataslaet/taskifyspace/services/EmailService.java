package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.SendingEmailDTO;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import java.util.Date;

@Service
public class EmailService {

    @Value("${spring.mail.username}")
    private String emailFrom;

    private final JavaMailSender javaMailSender;

    public EmailService(JavaMailSender javaMailSender) {
        this.javaMailSender = javaMailSender;
    }

    public void sendEmail(SendingEmailDTO sendingEmailDTO) {
        try {
            SimpleMailMessage simpleMailMessage = new SimpleMailMessage();
            simpleMailMessage.setSentDate(new Date());
            simpleMailMessage.setTo(sendingEmailDTO.to());
            simpleMailMessage.setFrom(emailFrom);
            simpleMailMessage.setSubject(sendingEmailDTO.subject());
            simpleMailMessage.setCc(sendingEmailDTO.cc());
            simpleMailMessage.setText(sendingEmailDTO.body());
            javaMailSender.send(simpleMailMessage);
        } catch (Exception e) {
            throw new com.jonataslaet.taskifyspace.exceptions.EmailException("Falha ao enviar email");
        }
    }

}
