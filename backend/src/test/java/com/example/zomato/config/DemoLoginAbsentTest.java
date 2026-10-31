package com.example.zomato.config;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Outside the demo and dev profiles there is no demo sign-in at all. */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:demo_login_absent;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
class DemoLoginAbsentTest {

    @Autowired MockMvc mvc;

    @Test
    void theEndpointDoesNotExistInTheDefaultProfile() throws Exception {
        mvc.perform(post("/api/auth/demo-login").contentType(MediaType.APPLICATION_JSON).content("{\"role\":\"ADMIN\"}")).andExpect(status().isNotFound());
    }
}
