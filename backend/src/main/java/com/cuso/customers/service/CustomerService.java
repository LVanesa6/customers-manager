package com.cuso.customers.service;

import com.cuso.customers.dto.CustomerFilter;
import com.cuso.customers.dto.CustomerRequest;
import com.cuso.customers.dto.CustomerResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface CustomerService {

    Page<CustomerResponse> findAll(Pageable pageable, CustomerFilter filter);

    CustomerResponse findById(Long id);

    CustomerResponse create(CustomerRequest request);

    CustomerResponse update(Long id, CustomerRequest request);

    void delete(Long id);
}
