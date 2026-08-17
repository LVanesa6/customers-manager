package com.cuso.customers.service;

import com.cuso.customers.dto.CustomerRequest;
import com.cuso.customers.dto.CustomerResponse;
import com.cuso.customers.entity.Customer;
import com.cuso.customers.exception.DuplicateResourceException;
import com.cuso.customers.exception.ResourceNotFoundException;
import com.cuso.customers.mapper.CustomerMapper;
import com.cuso.customers.mapper.CustomerMapperImpl;
import com.cuso.customers.repository.CustomerRepository;
import com.cuso.customers.service.impl.CustomerServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CustomerServiceImplTest {

    @Mock
    private CustomerRepository customerRepository;

    private final CustomerMapper customerMapper = new CustomerMapperImpl();

    private CustomerServiceImpl customerService;

    @BeforeEach
    void setUp() {
        customerService = new CustomerServiceImpl(customerRepository, customerMapper);
    }

    @Test
    void create_persistsCustomer_whenEmailIsUnique() {
        CustomerRequest request = new CustomerRequest("Ana Gomez", "ana.gomez@cuso.com", "3001234567", "Calle 1");

        Customer saved = Customer.builder()
                .id(10L).name("Ana Gomez").email("ana.gomez@cuso.com")
                .phone("3001234567").address("Calle 1")
                .registrationDate(LocalDate.now())
                .build();

        when(customerRepository.existsByEmailIgnoreCase("ana.gomez@cuso.com")).thenReturn(false);
        when(customerRepository.save(any(Customer.class))).thenReturn(saved);

        CustomerResponse response = customerService.create(request);

        assertThat(response.id()).isEqualTo(10L);
        assertThat(response.name()).isEqualTo("Ana Gomez");
        assertThat(response.email()).isEqualTo("ana.gomez@cuso.com");
    }

    @Test
    void create_throwsDuplicateResourceException_whenEmailAlreadyExists() {
        CustomerRequest request = new CustomerRequest("Ana Gomez", "ana.gomez@cuso.com", null, null);

        when(customerRepository.existsByEmailIgnoreCase("ana.gomez@cuso.com")).thenReturn(true);

        assertThatThrownBy(() -> customerService.create(request))
                .isInstanceOf(DuplicateResourceException.class);

        verify(customerRepository, never()).save(any());
    }

    @Test
    void findById_throwsResourceNotFoundException_whenCustomerDoesNotExist() {
        when(customerRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> customerService.findById(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }
}
