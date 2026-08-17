package com.cuso.customers.dto;

public record UserResponse(
        String id,
        String username,
        String email,
        String firstName,
        String lastName,
        AppRole role
) {
}
