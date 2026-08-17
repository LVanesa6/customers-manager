package com.cuso.customers.service.impl;

import com.cuso.customers.dto.CustomerFilter;
import com.cuso.customers.dto.CustomerRequest;
import com.cuso.customers.dto.CustomerResponse;
import com.cuso.customers.entity.Customer;
import com.cuso.customers.exception.DuplicateResourceException;
import com.cuso.customers.exception.ResourceNotFoundException;
import com.cuso.customers.mapper.CustomerMapper;
import com.cuso.customers.repository.CustomerRepository;
import com.cuso.customers.repository.CustomerSpecifications;
import com.cuso.customers.service.CustomerService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

@Service
@RequiredArgsConstructor
@Transactional
public class CustomerServiceImpl implements CustomerService {

    private static final String CUSTOMER_RESOURCE = "Cliente";

    private final CustomerRepository customerRepository;
    private final CustomerMapper customerMapper;

    @Override
    @Transactional(readOnly = true)
    public Page<CustomerResponse> findAll(Pageable pageable, CustomerFilter filter) {
        Specification<Customer> spec = Specification
                .where(CustomerSpecifications.hasNameLike(filter.name()))
                .and(CustomerSpecifications.hasEmailLike(filter.email()))
                .and(CustomerSpecifications.hasPhoneLike(filter.phone()))
                .and(CustomerSpecifications.hasAddressLike(filter.address()))
                .and(CustomerSpecifications.registeredFrom(filter.registrationDateFrom()))
                .and(CustomerSpecifications.registeredTo(filter.registrationDateTo()));
        return customerRepository.findAll(spec, pageable).map(customerMapper::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public CustomerResponse findById(Long id) {
        return customerMapper.toResponse(getOrThrow(id));
    }

    @Override
    public CustomerResponse create(CustomerRequest request) {
        if (customerRepository.existsByEmailIgnoreCase(request.email())) {
            throw new DuplicateResourceException("Ya existe un cliente con el email '%s'".formatted(request.email()));
        }
        Customer entity = customerMapper.toEntity(request);
        entity.setRegistrationDate(LocalDate.now());
        return customerMapper.toResponse(customerRepository.save(entity));
    }

    @Override
    public CustomerResponse update(Long id, CustomerRequest request) {
        Customer entity = getOrThrow(id);
        if (customerRepository.existsByEmailIgnoreCaseAndIdNot(request.email(), id)) {
            throw new DuplicateResourceException("Ya existe un cliente con el email '%s'".formatted(request.email()));
        }
        customerMapper.updateEntityFromRequest(request, entity);
        return customerMapper.toResponse(customerRepository.save(entity));
    }

    @Override
    public void delete(Long id) {
        Customer entity = getOrThrow(id);
        customerRepository.delete(entity);
    }

    private Customer getOrThrow(Long id) {
        return customerRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException(CUSTOMER_RESOURCE, id));
    }
}
