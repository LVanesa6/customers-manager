package com.cuso.customers.exception;

public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String resource, Long id) {
        super("%s con id %d no fue encontrado".formatted(resource, id));
    }

    public ResourceNotFoundException(String resource, String id) {
        super("%s con id %s no fue encontrado".formatted(resource, id));
    }
}
