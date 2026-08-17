package com.cuso.customers.service;

import com.cuso.customers.dto.CreateUserRequest;
import com.cuso.customers.dto.ResetPasswordRequest;
import com.cuso.customers.dto.UpdateUserRequest;
import com.cuso.customers.dto.UserResponse;

import java.util.List;

public interface KeycloakAdminService {

    List<UserResponse> listUsers();

    UserResponse createUser(CreateUserRequest request);

    UserResponse updateUser(String id, UpdateUserRequest request);

    void deleteUser(String id, String requestingUsername);

    void resetPassword(String id, ResetPasswordRequest request);
}
