package com.example.zomato.security;

import com.example.zomato.entity.Notification;
import com.example.zomato.entity.User;
import com.example.zomato.repository.NotificationRepository;
import com.example.zomato.repository.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.util.Date;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

/** Notifications belong to one person: nobody else can read, mark or delete them, only an admin can create them, and no response carries the user record. */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:notif_security;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
class NotificationSecurityTest {

    private static final String A = "notif.a@cravey.test";
    private static final String B = "notif.b@cravey.test";

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired NotificationRepository notifications;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();

    private User a, b;
    private Notification mineA;

    @BeforeEach
    void setUp() {
        notifications.deleteAll();
        a = user(A);
        b = user(B);
        mineA = notification(a, "for A only", false, 1);
        notification(b, "for B only", false, 2);
    }

    private User user(String email) {
        return users.findFirstByEmailIgnoreCase(email).orElseGet(() -> {
            User u = new User("User " + email, email, "CUSTOMER");
            u.setPassword("$2a$10$thisIsAPasswordHashThatMustNeverLeak");
            u.setPasswordResetToken("reset-token-must-not-leak");
            return users.save(u);
        });
    }

    private Notification notification(User u, String text, boolean read, int hoursAgo) {
        Notification n = new Notification();
        n.setUser(u);
        n.setMessage(text);
        n.setType("TEST");
        n.setRead(read);
        n.setTimestamp(new Date(System.currentTimeMillis() - hoursAgo * 3600_000L));
        return notifications.save(n);
    }

    private MockHttpServletRequestBuilder as(MockHttpServletRequestBuilder r, String email, String role) {
        return r.header("Authorization", "Bearer " + jwt.generateToken(email, role));
    }

    private int code(MockHttpServletRequestBuilder r) throws Exception { return mvc.perform(r).andReturn().getResponse().getStatus(); }

    @Test
    void signedOutIs401() throws Exception {
        assertEquals(401, code(get("/api/notifications/" + mineA.getId())));
        assertEquals(401, code(get("/api/notifications/user/" + a.getUserId())));
        assertEquals(401, code(get("/api/notifications/mine")));
    }

    @Test
    void someoneElseCannotReadMarkOrDeleteMine() throws Exception {
        int id = mineA.getId();
        assertEquals(403, code(as(get("/api/notifications/" + id), B, "CUSTOMER")));
        assertEquals(403, code(as(get("/api/notifications/user/" + a.getUserId()), B, "CUSTOMER")));
        assertEquals(403, code(as(get("/api/notifications/user/" + a.getUserId() + "/unread"), B, "CUSTOMER")));
        assertEquals(403, code(as(put("/api/notifications/" + id + "/read"), B, "CUSTOMER")));
        assertEquals(403, code(as(delete("/api/notifications/" + id), B, "CUSTOMER")));
        Notification still = notifications.findById(id).orElseThrow();
        assertFalse(still.isRead(), "not marked");
        assertEquals("for A only", still.getMessage());
    }

    @Test
    void anOwnerOrDeliveryRoleDoesNotChangeThat() throws Exception {
        assertEquals(403, code(as(get("/api/notifications/" + mineA.getId()), B, "OWNER")));
        assertEquals(403, code(as(delete("/api/notifications/" + mineA.getId()), B, "DELIVERY_PARTNER")));
    }

    @Test
    void iCanUseMyOwnAndMarkThemRead() throws Exception {
        int id = mineA.getId();
        assertEquals(200, code(as(get("/api/notifications/" + id), A, "CUSTOMER")));
        assertEquals(200, code(as(get("/api/notifications/user/" + a.getUserId()), A, "CUSTOMER")));
        assertEquals(200, code(as(put("/api/notifications/" + id + "/read"), A, "CUSTOMER")));
        assertTrue(notifications.findById(id).orElseThrow().isRead());
        assertEquals(200, code(as(delete("/api/notifications/" + id), A, "CUSTOMER")));
        assertTrue(notifications.findById(id).isEmpty());
    }

    @Test
    void mineListsOnlyMyOwnNewestFirstAndUnreadFilters() throws Exception {
        notification(a, "older and read", true, 10);
        JsonNode all = json.readTree(mvc.perform(as(get("/api/notifications/mine"), A, "CUSTOMER")).andReturn().getResponse().getContentAsString());
        assertEquals(2, all.size());
        assertEquals("for A only", all.get(0).get("message").asText(), "newest first");
        for (JsonNode n : all) assertEquals(a.getUserId(), n.get("userId").asInt());
        JsonNode unread = json.readTree(mvc.perform(as(get("/api/notifications/mine/unread"), A, "CUSTOMER")).andReturn().getResponse().getContentAsString());
        assertEquals(1, unread.size());
        assertFalse(unread.get(0).get("isRead").asBoolean());
    }

    @Test
    void readAllMarksOnlyMyOwn() throws Exception {
        notification(a, "second for A", false, 3);
        JsonNode r = json.readTree(mvc.perform(as(put("/api/notifications/mine/read-all"), A, "CUSTOMER")).andReturn().getResponse().getContentAsString());
        assertEquals(2, r.get("marked").asInt());
        assertTrue(notifications.findByUser_UserId(a.getUserId()).stream().allMatch(Notification::isRead));
        assertTrue(notifications.findByUser_UserId(b.getUserId()).stream().noneMatch(Notification::isRead), "B's are untouched");
        assertEquals(0, json.readTree(mvc.perform(as(put("/api/notifications/mine/read-all"), A, "CUSTOMER")).andReturn().getResponse().getContentAsString()).get("marked").asInt());
        assertEquals(401, code(put("/api/notifications/mine/read-all")));
    }

    @Test
    void anAdminCanSeeAnyone() throws Exception {
        assertEquals(200, code(as(get("/api/notifications/" + mineA.getId()), "admin@cravey.test", "ADMIN")));
        assertEquals(200, code(as(get("/api/notifications/user/" + a.getUserId()), "admin@cravey.test", "ADMIN")));
    }

    @Test
    void onlyAnAdminCanCreateOne() throws Exception {
        String body = "{\"user\":{\"userId\":" + b.getUserId() + "},\"message\":\"you won a prize\",\"type\":\"PHISH\"}";
        assertEquals(403, code(as(post("/api/notifications").contentType(MediaType.APPLICATION_JSON).content(body), A, "CUSTOMER")), "A cannot write into B's inbox");
        assertEquals(1, notifications.findByUser_UserId(b.getUserId()).size());
        assertEquals(200, code(as(post("/api/notifications").contentType(MediaType.APPLICATION_JSON).content(body), "admin@cravey.test", "ADMIN")));
        assertEquals(2, notifications.findByUser_UserId(b.getUserId()).size());
    }

    @Test
    void anUnknownNotificationIs404NotA500() throws Exception {
        assertEquals(404, code(as(get("/api/notifications/999999"), A, "CUSTOMER")));
    }

    @Test
    void noResponseCarriesThePasswordHashOrTokens() throws Exception {
        for (String url : new String[]{"/api/notifications/" + mineA.getId(), "/api/notifications/user/" + a.getUserId(), "/api/notifications/mine"}) {
            String body = mvc.perform(as(get(url), A, "CUSTOMER")).andReturn().getResponse().getContentAsString();
            assertFalse(body.contains("thisIsAPasswordHash") || body.toLowerCase().contains("password") || body.contains("reset-token") || body.contains(A), url + " leaked: " + body);
        }
        String created = mvc.perform(as(post("/api/notifications").contentType(MediaType.APPLICATION_JSON)
                .content("{\"user\":{\"userId\":" + a.getUserId() + "},\"message\":\"hi\",\"type\":\"T\"}"), "admin@cravey.test", "ADMIN")).andReturn().getResponse().getContentAsString();
        assertFalse(created.toLowerCase().contains("password"), created);
    }
}
