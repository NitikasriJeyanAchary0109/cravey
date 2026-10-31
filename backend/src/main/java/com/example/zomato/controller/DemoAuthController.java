package com.example.zomato.controller;

import com.example.zomato.entity.User;
import com.example.zomato.repository.UserRepository;
import com.example.zomato.security.JwtService;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

/**
 * The app's "Quick Demo Sign-In". It exists only in the {@code demo} and {@code dev} profiles, so a production backend has no such endpoint
 * and the app carries no signing key. It signs in as one of four fixed demo accounts (the ones DataInitializer creates with no password) and
 * nobody else: you cannot ask for an arbitrary email.
 */
@RestController
@Profile({"demo", "dev"})
@RequestMapping("/api/auth")
public class DemoAuthController {

    /** 12 hours: demo sign-in has no refresh token. */
    static final long DEMO_TOKEN_SECONDS = 12 * 3600L;

    private static final Map<String, String> EMAIL_BY_ROLE = Map.of(
            "CUSTOMER", "aarav.sharma@gmail.com",
            "OWNER", "arunkumar2006.d@gmail.com",
            "DELIVERY", "rahul.singh@gmail.com",
            "ADMIN", "admin1@zomato.com");

    public record DemoLoginRequest(String role) {}

    private final UserRepository users;
    private final JwtService jwt;

    public DemoAuthController(UserRepository users, JwtService jwt) {
        this.users = users;
        this.jwt = jwt;
    }

    @PostMapping("/demo-login")
    public Map<String, Object> demoLogin(@RequestBody DemoLoginRequest request) {
        String role = normalize(request == null ? null : request.role());
        String email = EMAIL_BY_ROLE.get(role);
        if (email == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose CUSTOMER, OWNER, DELIVERY or ADMIN.");
        User user = users.findFirstByEmailIgnoreCase(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "The demo account for " + role + " does not exist yet."));
        String token = jwt.generateToken(user.getEmail(), user.getRole(), user.getUserId(), user.getName(), DEMO_TOKEN_SECONDS);
        return Map.of("accessToken", token, "email", user.getEmail(), "name", user.getName() == null ? "" : user.getName(),
                "role", user.getRole(), "userId", user.getUserId());
    }

    private static String normalize(String role) {
        String r = role == null ? "" : role.trim().toUpperCase();
        return switch (r) {
            case "RESTAURANT" -> "OWNER";
            case "DELIVERY_PARTNER" -> "DELIVERY";
            default -> r;
        };
    }
}
