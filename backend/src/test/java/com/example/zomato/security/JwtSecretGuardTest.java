package com.example.zomato.security;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

/** The signing key published in the repository can sign a token for any account, so a production start must not accept it. */
class JwtSecretGuardTest {

    private static JwtService service(String secret, String... profiles) {
        JwtService s = new JwtService();
        ReflectionTestUtils.setField(s, "secret", secret);
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles(profiles);
        ReflectionTestUtils.setField(s, "environment", env);
        return s;
    }

    @Test
    void theProdProfileRefusesToStartOnTheKnownDefault() {
        for (String profile : new String[]{"prod", "production"}) {
            var e = assertThrows(IllegalStateException.class, () -> service(JwtService.KNOWN_DEFAULT_SECRET, profile).verifySecret());
            assertTrue(e.getMessage().contains("JWT_SECRET"));
        }
    }

    @Test
    void aRealSecretIsAcceptedEverywhere() {
        assertDoesNotThrow(() -> service("a-long-random-secret-nobody-has-seen-0123456789abcdef", "prod").verifySecret());
        assertDoesNotThrow(() -> service("a-long-random-secret-nobody-has-seen-0123456789abcdef").verifySecret());
    }

    @Test
    void devDemoAndTestProfilesMayUseTheDefaultWithOnlyAWarning() {
        for (String profile : new String[]{"dev", "demo", "test"}) {
            JwtService s = service(JwtService.KNOWN_DEFAULT_SECRET, profile);
            assertDoesNotThrow(s::verifySecret);
            assertEquals(JwtService.KNOWN_DEFAULT_SECRET, ReflectionTestUtils.getField(s, "secret"), profile + " keeps the published key");
        }
    }

    @Test
    void anyOtherRunNeverSignsWithThePublishedKey() {
        for (String[] profiles : new String[][]{{}, {"staging"}, {"qa", "metrics"}}) {
            JwtService s = service(JwtService.KNOWN_DEFAULT_SECRET, profiles);
            assertDoesNotThrow(s::verifySecret);
            String used = (String) ReflectionTestUtils.getField(s, "secret");
            assertNotEquals(JwtService.KNOWN_DEFAULT_SECRET, used, "profiles " + java.util.Arrays.toString(profiles));
            assertTrue(used.length() >= 48, "long enough for HS256");
            // a token signed with the published key is rejected, while the process's own tokens still verify
            JwtService attacker = service(JwtService.KNOWN_DEFAULT_SECRET, "dev");
            String forged = attacker.generateToken("admin@cravey.com", "ADMIN");
            assertThrows(Exception.class, () -> s.extractUsername(forged));
            assertEquals("a@b.com", s.extractUsername(s.generateToken("a@b.com", "CUSTOMER")));
        }
    }

    @Test
    void eachProcessGetsItsOwnRandomKey() {
        JwtService one = service(JwtService.KNOWN_DEFAULT_SECRET);
        JwtService two = service(JwtService.KNOWN_DEFAULT_SECRET);
        one.verifySecret();
        two.verifySecret();
        assertNotEquals(ReflectionTestUtils.getField(one, "secret"), ReflectionTestUtils.getField(two, "secret"));
    }

    @Test
    void theConstantMatchesTheShippedConfiguration() throws Exception {
        String yml = java.nio.file.Files.readString(java.nio.file.Path.of("src/main/resources/application.yml"));
        assertTrue(yml.contains("${JWT_SECRET:" + JwtService.KNOWN_DEFAULT_SECRET + "}"), "the guard must check the same value the config falls back to");
    }
}
