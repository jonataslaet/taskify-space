package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import org.springframework.beans.BeanUtils;

public class SpaceMapper {

    public static Space toEntity(SpaceRecordDTO spaceRecordDTO) {
        Space Space = new Space();
        BeanUtils.copyProperties(spaceRecordDTO, Space);
        return Space;
    }

    public static SpaceRecordDTO toDTO(Space space) {
        return new SpaceRecordDTO(space.getId(), space.getName(), space.getActive());
    }
}
