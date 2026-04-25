package com.jonataslaet.taskifyspace.entities.enums;

public enum UserStatusEnum {

    PENDING_EVALUATION(1, "Aguardando avaliação"),
    ACTIVE(2, "Ativo"),
    SUSPENDED(3, "Suspenso");

    private final Integer id;
    private final String name;

    UserStatusEnum(Integer id, String name) {
        this.id = id;
        this.name = name;
    }

    public Integer getId() {
        return id;
    }

    public String getName() {
        return name;
    }

}
