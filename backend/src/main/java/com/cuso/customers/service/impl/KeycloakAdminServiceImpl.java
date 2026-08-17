package com.cuso.customers.service.impl;

import com.cuso.customers.dto.AppRole;
import com.cuso.customers.dto.CreateUserRequest;
import com.cuso.customers.dto.ResetPasswordRequest;
import com.cuso.customers.dto.UpdateUserRequest;
import com.cuso.customers.dto.UserResponse;
import com.cuso.customers.exception.BusinessRuleException;
import com.cuso.customers.exception.DuplicateResourceException;
import com.cuso.customers.exception.ResourceNotFoundException;
import com.cuso.customers.service.KeycloakAdminService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

/**
 * Habla directo con la Admin REST API de Keycloak usando una cuenta de
 * servicio propia (cliente confidencial "customers-admin-service" con el rol
 * manage-users de realm-management) -- asi el navegador nunca ve un token con
 * privilegios de administrador de Keycloak, solo el rol de negocio ADMIN de
 * esta app.
 */
@Service
public class KeycloakAdminServiceImpl implements KeycloakAdminService {

    private static final String REALM = "customers-realm";
    private static final String USER_RESOURCE = "Usuario";

    private final RestClient restClient = RestClient.create();
    private final String adminBaseUri;
    private final String adminClientId;
    private final String adminClientSecret;

    public KeycloakAdminServiceImpl(
            @Value("${app.security.keycloak.admin.base-uri}") String adminBaseUri,
            @Value("${app.security.keycloak.admin.client-id}") String adminClientId,
            @Value("${app.security.keycloak.admin.client-secret}") String adminClientSecret) {
        this.adminBaseUri = adminBaseUri;
        this.adminClientId = adminClientId;
        this.adminClientSecret = adminClientSecret;
    }

    @Override
    public List<UserResponse> listUsers() {
        String token = fetchServiceAccountToken();
        List<Map<String, Object>> users = restClient.get()
                .uri(usersUri() + "?max=200")
                .header(HttpHeaders.AUTHORIZATION, bearer(token))
                .retrieve()
                .body(new ParameterizedTypeReference<>() {
                });

        return users.stream()
                .map(u -> toUserResponse(u, fetchAssignedRole((String) u.get("id"), token)))
                .toList();
    }

    @Override
    public UserResponse createUser(CreateUserRequest request) {
        String token = fetchServiceAccountToken();

        Map<String, Object> payload = Map.of(
                "username", request.username(),
                "email", request.email(),
                "firstName", request.firstName(),
                "lastName", request.lastName(),
                "enabled", true,
                "emailVerified", true,
                "credentials", List.of(Map.of(
                        "type", "password",
                        "value", request.password(),
                        "temporary", true
                ))
        );

        ResponseEntity<Void> response = restClient.post()
                .uri(usersUri())
                .header(HttpHeaders.AUTHORIZATION, bearer(token))
                .contentType(MediaType.APPLICATION_JSON)
                .body(payload)
                .retrieve()
                .onStatus(status -> status.value() == 409, (req, res) -> {
                    throw new DuplicateResourceException(
                            "Ya existe un usuario con ese nombre de usuario o email");
                })
                .toBodilessEntity();

        String userId = extractId(response);
        assignRole(userId, request.role(), token);

        return new UserResponse(userId, request.username(), request.email(),
                request.firstName(), request.lastName(), request.role());
    }

    @Override
    public UserResponse updateUser(String id, UpdateUserRequest request) {
        String token = fetchServiceAccountToken();

        Map<String, Object> payload = Map.of(
                "email", request.email(),
                "firstName", request.firstName(),
                "lastName", request.lastName()
        );

        restClient.put()
                .uri(usersUri() + "/" + id)
                .header(HttpHeaders.AUTHORIZATION, bearer(token))
                .contentType(MediaType.APPLICATION_JSON)
                .body(payload)
                .retrieve()
                .onStatus(status -> status.value() == 404, (req, res) -> {
                    throw new ResourceNotFoundException(USER_RESOURCE, id);
                })
                .onStatus(status -> status.value() == 409, (req, res) -> {
                    throw new DuplicateResourceException(
                            "Ya existe otro usuario con ese email");
                })
                .toBodilessEntity();

        replaceRole(id, request.role(), token);

        Map<String, Object> user = restClient.get()
                .uri(usersUri() + "/" + id)
                .header(HttpHeaders.AUTHORIZATION, bearer(token))
                .retrieve()
                .body(new ParameterizedTypeReference<>() {
                });

        return toUserResponse(user, request.role());
    }

    @Override
    public void deleteUser(String id, String requestingUsername) {
        String token = fetchServiceAccountToken();

        Map<String, Object> user = restClient.get()
                .uri(usersUri() + "/" + id)
                .header(HttpHeaders.AUTHORIZATION, bearer(token))
                .retrieve()
                .onStatus(status -> status.value() == 404, (req, res) -> {
                    throw new ResourceNotFoundException(USER_RESOURCE, id);
                })
                .body(new ParameterizedTypeReference<>() {
                });

        if (requestingUsername.equalsIgnoreCase((String) user.get("username"))) {
            throw new BusinessRuleException("No puedes eliminar tu propio usuario");
        }

        restClient.delete()
                .uri(usersUri() + "/" + id)
                .header(HttpHeaders.AUTHORIZATION, bearer(token))
                .retrieve()
                .toBodilessEntity();
    }

    @Override
    public void resetPassword(String id, ResetPasswordRequest request) {
        String token = fetchServiceAccountToken();

        Map<String, Object> payload = Map.of(
                "type", "password",
                "value", request.password(),
                "temporary", true
        );

        restClient.put()
                .uri(usersUri() + "/" + id + "/reset-password")
                .header(HttpHeaders.AUTHORIZATION, bearer(token))
                .contentType(MediaType.APPLICATION_JSON)
                .body(payload)
                .retrieve()
                .onStatus(status -> status.value() == 404, (req, res) -> {
                    throw new ResourceNotFoundException(USER_RESOURCE, id);
                })
                .toBodilessEntity();
    }

    private void assignRole(String userId, AppRole role, String token) {
        Map<String, Object> roleRep = restClient.get()
                .uri(realmUri() + "/roles/" + role.name())
                .header(HttpHeaders.AUTHORIZATION, bearer(token))
                .retrieve()
                .body(new ParameterizedTypeReference<>() {
                });

        restClient.post()
                .uri(usersUri() + "/" + userId + "/role-mappings/realm")
                .header(HttpHeaders.AUTHORIZATION, bearer(token))
                .contentType(MediaType.APPLICATION_JSON)
                .body(List.of(roleRep))
                .retrieve()
                .toBodilessEntity();
    }

    /**
     * Los roles de la app son mutuamente excluyentes (a cada usuario le
     * corresponde uno solo), asi que al editar hay que quitar cualquier rol
     * previo antes de asignar el nuevo -- si no, alguien que baja de ADMIN a
     * USER se quedaria con el ADMIN asignado directamente y seguiria
     * teniendo acceso total.
     */
    private void replaceRole(String userId, AppRole newRole, String token) {
        List<Map<String, Object>> current = restClient.get()
                .uri(usersUri() + "/" + userId + "/role-mappings/realm")
                .header(HttpHeaders.AUTHORIZATION, bearer(token))
                .retrieve()
                .body(new ParameterizedTypeReference<>() {
                });

        List<Map<String, Object>> appRoles = current.stream()
                .filter(r -> isAppRole((String) r.get("name")))
                .toList();

        if (!appRoles.isEmpty()) {
            restClient.method(HttpMethod.DELETE)
                    .uri(usersUri() + "/" + userId + "/role-mappings/realm")
                    .header(HttpHeaders.AUTHORIZATION, bearer(token))
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(appRoles)
                    .retrieve()
                    .toBodilessEntity();
        }

        assignRole(userId, newRole, token);
    }

    private boolean isAppRole(String name) {
        for (AppRole role : AppRole.values()) {
            if (role.name().equals(name)) {
                return true;
            }
        }
        return false;
    }

    private AppRole fetchAssignedRole(String userId, String token) {
        List<Map<String, Object>> roles = restClient.get()
                .uri(usersUri() + "/" + userId + "/role-mappings/realm")
                .header(HttpHeaders.AUTHORIZATION, bearer(token))
                .retrieve()
                .body(new ParameterizedTypeReference<>() {
                });

        return roles.stream()
                .map(r -> (String) r.get("name"))
                .filter(this::isAppRole)
                .findFirst()
                .map(AppRole::valueOf)
                .orElse(null);
    }

    private UserResponse toUserResponse(Map<String, Object> u, AppRole role) {
        return new UserResponse(
                (String) u.get("id"),
                (String) u.get("username"),
                (String) u.get("email"),
                (String) u.get("firstName"),
                (String) u.get("lastName"),
                role
        );
    }

    private String fetchServiceAccountToken() {
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("grant_type", "client_credentials");
        form.add("client_id", adminClientId);
        form.add("client_secret", adminClientSecret);

        Map<String, Object> response = restClient.post()
                .uri(adminBaseUri + "/realms/" + REALM + "/protocol/openid-connect/token")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .body(form)
                .retrieve()
                .body(new ParameterizedTypeReference<>() {
                });

        return (String) response.get("access_token");
    }

    private String extractId(ResponseEntity<Void> response) {
        String location = response.getHeaders().getLocation().toString();
        return location.substring(location.lastIndexOf('/') + 1);
    }

    private String bearer(String token) {
        return "Bearer " + token;
    }

    private String usersUri() {
        return realmUri() + "/users";
    }

    private String realmUri() {
        return adminBaseUri + "/admin/realms/" + REALM;
    }
}
