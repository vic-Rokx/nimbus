
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>

#define PORT 8080
#define BUFFER_SIZE 1024
#define MAX_EVENTS 10

// Set a file descriptor to non-blocking mode
int set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags == -1) {
        perror("fcntl F_GETFL");
        return -1;
    }
    if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) == -1) {
        perror("fcntl F_SETFL");
        return -1;
    }
    return 0;
}

// Simulate a blocking operation with a delay (in seconds)
void simulate_blocking_operation(int delay) {
    time_t start = time(NULL);
    while (time(NULL) - start < delay) {
        // Busy-waiting to simulate a blocking task
    }
}

char* extract_path(const char* request) {
    static char path[1024];  // Static buffer to store the path
    char method[10];
    
    // Parse the request line to get the path
    // This will extract everything between the first space and either the second space or HTTP/
    if (sscanf(request, "%s %[^ HTTP]", method, path) == 2) {
        return path;
    }
    
    return NULL;  // Return NULL if parsing fails
}

int main() {
    int server_fd, client_fd, kq;
    struct sockaddr_in address;
    struct kevent events[MAX_EVENTS]; // Array for returned events
    struct kevent change_event;      // For registering new events
    char buffer[BUFFER_SIZE];
    int opt = 1;

    // Create a socket
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("socket failed");
        exit(EXIT_FAILURE);
    }

    // Set the socket to allow address reuse
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt))) {
        perror("setsockopt");
        close(server_fd);
        exit(EXIT_FAILURE);
    }

    // Configure server address
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);

    // Bind the socket to the address
    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("bind failed");
        close(server_fd);
        exit(EXIT_FAILURE);
    }

    // Set the socket to listen for incoming connections
    if (listen(server_fd, SOMAXCONN) < 0) {
        perror("listen");
        close(server_fd);
        exit(EXIT_FAILURE);
    }

    // Set the server socket to non-blocking mode
    if (set_nonblocking(server_fd) < 0) {
        close(server_fd);
        exit(EXIT_FAILURE);
    }

    // Create a kqueue instance
    if ((kq = kqueue()) == -1) {
        perror("kqueue");
        close(server_fd);
        exit(EXIT_FAILURE);
    }

    // Register the server socket for monitoring
    EV_SET(&change_event, server_fd, EVFILT_READ, EV_ADD | EV_ENABLE, 0, 0, NULL);
    if (kevent(kq, &change_event, 1, NULL, 0, NULL) == -1) {
        perror("kevent");
        close(server_fd);
        close(kq);
        exit(EXIT_FAILURE);
    }

    printf("Server is running on port %d\n", PORT);

    while (1) {
        int n = kevent(kq, NULL, 0, events, MAX_EVENTS, NULL);
        if (n == -1) {
            perror("kevent wait");
            break;
        }

        for (int i = 0; i < n; i++) {
            if (events[i].flags & EV_ERROR) {
                // Handle error events
                fprintf(stderr, "Kqueue error on fd %d\n", (int)events[i].ident);
                close((int)events[i].ident);
                continue;
            }

            if (events[i].ident == server_fd) {
                // Accept new connections
                while ((client_fd = accept(server_fd, NULL, NULL)) != -1) {
                    printf("New client connected: %d\n", client_fd);
                    set_nonblocking(client_fd);

                    EV_SET(&change_event, client_fd, EVFILT_READ, EV_ADD | EV_ENABLE, 0, 0, NULL);
                    kevent(kq, &change_event, 1, NULL, 0, NULL);
                }
                if (errno != EAGAIN && errno != EWOULDBLOCK) {
                    perror("accept");
                }
            } else {
                // Handle client data
                client_fd = (int)events[i].ident;
                int bytes_read = read(client_fd, buffer, sizeof(buffer) - 1);

                if (bytes_read > 0) {
                    buffer[bytes_read] = '\0';
                    printf("Received from client %d:\n%s\n", client_fd, buffer);


if (strcmp(extract_path(buffer), "/fast") == 0) {
    // "Fast" endpoint
    const char *body = "Fast response: Immediate!\n";
    char response[1024];
    snprintf(response, sizeof(response), 
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: text/plain\r\n"
        "Content-Length: %lu\r\n"
        "Connection: close\r\n"
        "\r\n"
        "%s", 
        strlen(body), body);
    write(client_fd, response, strlen(response));
} else {
    // "Block" endpoint
    simulate_blocking_operation(5);
    const char *body = "Block response: Delayed 5 seconds\n";
    char response[1024];
    snprintf(response, sizeof(response), 
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: text/plain\r\n"
        "Content-Length: %lu\r\n"
        "Connection: close\r\n"
        "\r\n"
        "%s", 
        strlen(body), body);
    write(client_fd, response, strlen(response));
}


                    // const char *response = "Hello from the server!\n";
                    // write(client_fd, response, strlen(response));
                } else if (bytes_read == 0) {
                    printf("Client disconnected: %d\n", client_fd);
                    close(client_fd);
                } else {
                    perror("read");
                    close(client_fd);
                }
            }
        }
    }

    close(server_fd);
    close(kq);
    return 0;
}

