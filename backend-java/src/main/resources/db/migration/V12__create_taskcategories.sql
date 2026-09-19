CREATE TABLE taskcategories (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE,
    user_id BIGINT,
    space_id BIGINT NOT NULL,
    CONSTRAINT fk_taskcategories_creator
        FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_taskcategories_space
        FOREIGN KEY (space_id) REFERENCES spaces (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX uq_taskcategories_space_name_lower
    ON taskcategories (space_id, LOWER(name));
