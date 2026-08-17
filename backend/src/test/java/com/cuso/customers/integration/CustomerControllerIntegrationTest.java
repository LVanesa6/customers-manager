package com.cuso.customers.integration;

import com.cuso.customers.repository.CustomerRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class CustomerControllerIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private CustomerRepository customerRepository;

    @BeforeEach
    void cleanUp() {
        customerRepository.deleteAll();
    }

    @Test
    void create_returns201_whenAuthenticatedAsManager() throws Exception {
        String body = """
                {
                  "name": "Ana Gomez",
                  "email": "ana.gomez@cuso.com",
                  "phone": "3001234567",
                  "address": "Calle 1 # 2-34"
                }
                """;

        mockMvc.perform(post("/api/customers")
                        .with(jwt().authorities(() -> "ROLE_MANAGER"))
                        .contentType("application/json")
                        .content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.email").value("ana.gomez@cuso.com"))
                .andExpect(jsonPath("$.name").value("Ana Gomez"))
                .andExpect(jsonPath("$.registrationDate").exists());
    }

    @Test
    void create_returns403_whenAuthenticatedAsUserOnly() throws Exception {
        String body = """
                {
                  "name": "Ana Gomez",
                  "email": "ana.gomez@cuso.com"
                }
                """;

        mockMvc.perform(post("/api/customers")
                        .with(jwt().authorities(() -> "ROLE_USER"))
                        .contentType("application/json")
                        .content(body))
                .andExpect(status().isForbidden());
    }

    @Test
    void create_returns401_whenNotAuthenticated() throws Exception {
        String body = """
                {
                  "name": "Ana Gomez",
                  "email": "ana.gomez@cuso.com"
                }
                """;

        mockMvc.perform(post("/api/customers")
                        .contentType("application/json")
                        .content(body))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void delete_returns403_whenAuthenticatedAsUserWithoutAdminRole() throws Exception {
        var customer = customerRepository.save(com.cuso.customers.entity.Customer.builder()
                .name("Ana Gomez").email("ana.gomez@cuso.com")
                .registrationDate(java.time.LocalDate.now())
                .build());

        mockMvc.perform(delete("/api/customers/" + customer.getId())
                        .with(jwt().authorities(() -> "ROLE_USER")))
                .andExpect(status().isForbidden());
    }

    @Test
    void findAll_returns200_whenAuthenticatedWithAnyRole() throws Exception {
        mockMvc.perform(get("/api/customers")
                        .with(jwt().authorities(() -> "ROLE_USER"))
                        .param("page", "0").param("size", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(0));
    }

    @Test
    void findAll_returns401_whenNotAuthenticated() throws Exception {
        mockMvc.perform(get("/api/customers").param("page", "0").param("size", "10"))
                .andExpect(status().isUnauthorized());
    }
}
