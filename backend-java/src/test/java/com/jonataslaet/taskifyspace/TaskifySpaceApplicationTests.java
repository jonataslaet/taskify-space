package com.jonataslaet.taskifyspace;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@ActiveProfiles("test")
@SpringBootTest(properties = {
	"spring.datasource.url=jdbc:h2:mem:taskify-context-test",
	"spring.datasource.driver-class-name=org.h2.Driver",
	"spring.datasource.username=sa",
	"spring.datasource.password=",
	"spring.jpa.hibernate.ddl-auto=create-drop",
	"security.email.root=root@email.com",
	"security.password.root=password",
	"security.jwt.secret=test-secret",
	"cors.origins=http://localhost:3000"
})
class TaskifySpaceApplicationTests {

	@Test
	void contextLoads() {
	}

}
