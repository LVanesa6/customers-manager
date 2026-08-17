package com.cuso.customers.dto;

import java.time.LocalDate;

public record CustomerFilter(
        String name,
        String email,
        String phone,
        String address,
        LocalDate registrationDateFrom,
        LocalDate registrationDateTo
) {
}
