package com.cuso.customers;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;

@SpringBootApplication
public class CustomersServiceApplication {

    private static final Logger log = LoggerFactory.getLogger(CustomersServiceApplication.class);

    public static void main(String[] args) {
        SpringApplication.run(CustomersServiceApplication.class, args);
    }

    @Bean
    CommandLineRunner logStartupInfo(
            Environment environment,
            @Value("${spring.application.name}") String appName,
            @Value("${app.startup-message}") String startupMessage) {
        return args -> log.info("{} | app={} | port={}", startupMessage, appName, environment.getProperty("server.port"));
    }
}
