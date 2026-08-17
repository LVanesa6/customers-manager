package com.cuso.customers.mapper;

import com.cuso.customers.dto.CustomerRequest;
import com.cuso.customers.dto.CustomerResponse;
import com.cuso.customers.entity.Customer;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;

@Mapper(componentModel = "spring")
public interface CustomerMapper {

    CustomerResponse toResponse(Customer entity);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "registrationDate", ignore = true)
    Customer toEntity(CustomerRequest request);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "registrationDate", ignore = true)
    void updateEntityFromRequest(CustomerRequest request, @MappingTarget Customer entity);
}
