#include "tlsserver.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <openssl/ssl.h>
#include <openssl/err.h>

// Global variables to be accessed from Zig
SSL_CTX *global_ctx = NULL;
int global_server_sock = -1;

void init_openssl() {
    SSL_load_error_strings();
    OpenSSL_add_all_algorithms();
    SSL_library_init();
}

void cleanup_openssl() {
    EVP_cleanup();
}

SSL_CTX *create_ssl_context() {
    const SSL_METHOD *method = TLS_server_method();
    SSL_CTX *ctx = SSL_CTX_new(method);

    if (!ctx) {
        perror("Unable to create SSL context");
        ERR_print_errors_fp(stderr);
        return NULL;
    }

    return ctx;
}

int configure_ssl_context(SSL_CTX *ctx) {
    if (SSL_CTX_use_certificate_file(ctx, "cert.pem", SSL_FILETYPE_PEM) <= 0) {
        ERR_print_errors_fp(stderr);
        return -1;
    }

    if (SSL_CTX_use_PrivateKey_file(ctx, "key.pem", SSL_FILETYPE_PEM) <= 0) {
        ERR_print_errors_fp(stderr);
        return -1;
    }

    if (!SSL_CTX_check_private_key(ctx)) {
        fprintf(stderr, "Private key does not match the public certificate\n");
        return -1;
    }

    return 0;
}

int create_server_socket(int port) {
    int sock;
    struct sockaddr_in addr;

    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("Unable to create socket");
        return -1;
    }

    int enable = 1;
    if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int)) < 0) {
        perror("setsockopt(SO_REUSEADDR) failed");
        return -1;
    }

    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = INADDR_ANY;

    if (bind(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("Unable to bind");
        return -1;
    }

    if (listen(sock, 1) < 0) {
        perror("Unable to listen");
        return -1;
    }

    return sock;
}

// Function to be called from Zig to start the server
int start_tls_server(int port) {
    init_openssl();
    global_ctx = create_ssl_context();
    if (!global_ctx) return -1;

    if (configure_ssl_context(global_ctx) != 0) {
        SSL_CTX_free(global_ctx);
        return -1;
    }

    global_server_sock = create_server_socket(port);
    if (global_server_sock < 0) {
        SSL_CTX_free(global_ctx);
        return -1;
    }

    return 0;
}

// Function to accept new connection and return SSL object
SSL* accept_connection() {
    struct sockaddr_in addr;
    socklen_t len = sizeof(addr);
    
    int client_sock = accept(global_server_sock, (struct sockaddr*)&addr, &len);
    if (client_sock < 0) {
        return NULL;
    }

    SSL *ssl = SSL_new(global_ctx);
    if (!ssl) {
        close(client_sock);
        return NULL;
    }

    SSL_set_fd(ssl, client_sock);
    if (SSL_accept(ssl) <= 0) {
        SSL_free(ssl);
        close(client_sock);
        return NULL;
    }


    return ssl;
}

// Function to cleanup server
void cleanup_server() {
    if (global_server_sock != -1) {
        close(global_server_sock);
    }
    if (global_ctx) {
        SSL_CTX_free(global_ctx);
    }
    cleanup_openssl();
}
