package com.example.zomato.config;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Base64;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** "Quick Demo Sign-In" is issued by the backend (demo profile only), so the app needs no signing key. */
@SpringBootTest(properties = {"spring.profiles.active=demo", "spring.datasource.url=jdbc:h2:mem:demo_login;DB_CLOSE_DELAY=-1;MODE=PostgreSQL",
        "stripe.secret-key=sk_test_demo", "stripe.public-key=pk_test_demo", "stripe.webhook-secret=whsec_demo"})
@AutoConfigureMockMvc
class DemoLoginTest {

    @Autowired MockMvc mvc;
    private final ObjectMapper json = new ObjectMapper();

    private JsonNode login(String body) throws Exception {
        return json.readTree(mvc.perform(post("/api/auth/demo-login").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
    }

    @Test
    void eachRoleGetsATokenThatWorksForThatRoleOnly() throws Exception {
        JsonNode customer = login("{\"role\":\"CUSTOMER\"}");
        assertEquals("aarav.sharma@gmail.com", customer.get("email").asText());
        mvc.perform(get("/orders/my-orders").header("Authorization", "Bearer " + customer.get("accessToken").asText())).andExpect(status().isOk());
        mvc.perform(get("/admin/search/status").header("Authorization", "Bearer " + customer.get("accessToken").asText())).andExpect(status().isForbidden());

        JsonNode admin = login("{\"role\":\"ADMIN\"}");
        assertEquals("admin1@zomato.com", admin.get("email").asText());
        mvc.perform(get("/admin/search/status").header("Authorization", "Bearer " + admin.get("accessToken").asText())).andExpect(status().isOk());

        JsonNode owner = login("{\"role\":\"owner\"}");
        assertEquals("arunkumar2006.d@gmail.com", owner.get("email").asText());
        mvc.perform(get("/owner/insights").header("Authorization", "Bearer " + owner.get("accessToken").asText())).andExpect(status().isOk());

        assertEquals("rahul.singh@gmail.com", login("{\"role\":\"DELIVERY_PARTNER\"}").get("email").asText());
        assertEquals("arunkumar2006.d@gmail.com", login("{\"role\":\"RESTAURANT\"}").get("email").asText());
    }

    @Test
    void youCannotAskForAnArbitraryAccount() throws Exception {
        JsonNode r = login("{\"role\":\"CUSTOMER\",\"email\":\"admin@cravey.com\"}");
        assertEquals("aarav.sharma@gmail.com", r.get("email").asText(), "an email in the request is ignored");
        mvc.perform(post("/api/auth/demo-login").contentType(MediaType.APPLICATION_JSON).content("{\"role\":\"SUPERUSER\"}")).andExpect(status().isBadRequest());
        mvc.perform(post("/api/auth/demo-login").contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isBadRequest());
    }

    @Test
    void theTokenLastsTwelveHoursBecauseThereIsNoRefreshToken() throws Exception {
        String token = login("{\"role\":\"CUSTOMER\"}").get("accessToken").asText();
        JsonNode payload = json.readTree(Base64.getUrlDecoder().decode(token.split("\\.")[1]));
        assertEquals(12 * 3600, payload.get("exp").asLong() - payload.get("iat").asLong());
    }
}
