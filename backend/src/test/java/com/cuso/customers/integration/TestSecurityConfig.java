package com.cuso.customers.integration;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;

import java.time.Instant;

/**
 * Reemplaza el JwtDecoder real (que llamaria a Keycloak) por uno de prueba.
 * Los tests de integracion usan SecurityMockMvcRequestPostProcessors.jwt(...) para
 * inyectar la autenticacion directamente, por lo que este decoder nunca se invoca
 * realmente; solo existe para satisfacer el arranque del contexto de seguridad.
 */
@TestConfiguration
public class TestSecurityConfig {

    @Bean
    public JwtDecoder jwtDecoder() {
        return token -> Jwt.withTokenValue(token)
                .header("alg", "none")
                .claim("sub", "test-user")
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(3600))
                .build();
    }
}
