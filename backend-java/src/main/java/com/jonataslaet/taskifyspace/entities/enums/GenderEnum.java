package com.jonataslaet.taskifyspace.entities.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import org.springframework.http.converter.HttpMessageNotReadableException;

public enum GenderEnum {
    MALE,
    FEMALE;

    @JsonCreator
    public static GenderEnum from(String value) {
        for (GenderEnum gender : values()) {
            if (gender.name().equalsIgnoreCase(value)) {
                return gender;
            }
        }
        throw new HttpMessageNotReadableException("O valor "+ value +" é inválido", null);
    }
}

