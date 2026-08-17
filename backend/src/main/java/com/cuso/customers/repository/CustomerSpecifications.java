package com.cuso.customers.repository;

import com.cuso.customers.entity.Customer;
import org.springframework.data.jpa.domain.Specification;

import java.time.LocalDate;

public final class CustomerSpecifications {

    private CustomerSpecifications() {
    }

    public static Specification<Customer> hasNameLike(String name) {
        return (root, query, cb) -> name == null || name.isBlank()
                ? cb.conjunction()
                : cb.like(cb.lower(root.get("name")), "%" + name.toLowerCase() + "%");
    }

    public static Specification<Customer> hasEmailLike(String email) {
        return (root, query, cb) -> email == null || email.isBlank()
                ? cb.conjunction()
                : cb.like(cb.lower(root.get("email")), "%" + email.toLowerCase() + "%");
    }

    public static Specification<Customer> hasPhoneLike(String phone) {
        return (root, query, cb) -> phone == null || phone.isBlank()
                ? cb.conjunction()
                : cb.like(root.get("phone"), "%" + phone + "%");
    }

    public static Specification<Customer> hasAddressLike(String address) {
        return (root, query, cb) -> address == null || address.isBlank()
                ? cb.conjunction()
                : cb.like(cb.lower(root.get("address")), "%" + address.toLowerCase() + "%");
    }

    public static Specification<Customer> registeredFrom(LocalDate from) {
        return (root, query, cb) -> from == null
                ? cb.conjunction()
                : cb.greaterThanOrEqualTo(root.get("registrationDate"), from);
    }

    public static Specification<Customer> registeredTo(LocalDate to) {
        return (root, query, cb) -> to == null
                ? cb.conjunction()
                : cb.lessThanOrEqualTo(root.get("registrationDate"), to);
    }
}
