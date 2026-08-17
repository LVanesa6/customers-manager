package com.cuso.customers.dto;

import jakarta.validation.constraints.*;

public record CustomerRequest(

        @NotBlank(message = "El nombre es obligatorio")
        @Size(max = 150)
        String name,

        @NotBlank(message = "El email es obligatorio")
        @Email(message = "El email debe tener un formato valido")
        @Size(max = 150)
        String email,

        @Size(max = 30, message = "El telefono no puede superar los 30 caracteres")
        String phone,

        @Size(max = 200, message = "La direccion no puede superar los 200 caracteres")
        String address
) {
}
