package com.cuso.customers.dto;

import java.time.LocalDate;

public record CustomerResponse(
        Long id,
        String name,
        String email,
        String phone,
        String address,
        LocalDate registrationDate
) {
}
