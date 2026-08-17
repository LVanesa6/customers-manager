package com.cuso.customers.controller;

import com.cuso.customers.dto.CreateUserRequest;
import com.cuso.customers.dto.ResetPasswordRequest;
import com.cuso.customers.dto.UpdateUserRequest;
import com.cuso.customers.dto.UserResponse;
import com.cuso.customers.service.KeycloakAdminService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin/users")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
@Tag(name = "Admin - Usuarios", description = "Gestion de usuarios de la aplicacion (solo ADMIN)")
public class AdminUserController {

    private final KeycloakAdminService keycloakAdminService;

    @GetMapping
    @Operation(summary = "Listar usuarios de la app y su rol")
    public List<UserResponse> findAll() {
        return keycloakAdminService.listUsers();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Crear un usuario con un rol")
    public UserResponse create(@Valid @RequestBody CreateUserRequest request) {
        return keycloakAdminService.createUser(request);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Actualizar datos y rol de un usuario")
    public UserResponse update(@PathVariable String id, @Valid @RequestBody UpdateUserRequest request) {
        return keycloakAdminService.updateUser(id, request);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Eliminar un usuario")
    public ResponseEntity<Void> delete(@PathVariable String id, @AuthenticationPrincipal Jwt jwt) {
        keycloakAdminService.deleteUser(id, jwt.getClaimAsString("preferred_username"));
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/{id}/password")
    @Operation(summary = "Restablecer la contrasena de un usuario")
    public ResponseEntity<Void> resetPassword(@PathVariable String id, @Valid @RequestBody ResetPasswordRequest request) {
        keycloakAdminService.resetPassword(id, request);
        return ResponseEntity.noContent().build();
    }
}
