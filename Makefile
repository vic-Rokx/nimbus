# Variables
ZIG=zig
# SRC=main.zig

# Default target: Build and run
all: buildpgsql run

# Build the Zig codebase
build:
	$(ZIG) build 

# Build the Zig PGSQL 
buildpgsql:
	$(ZIG) build-exe -I./src/tls -I/opt/homebrew/opt/libpq/include -I/opt/homebrew/opt/openssl@3/include \
                 -L/opt/homebrew/opt/libpq/lib -L/opt/homebrew/opt/openssl@3/lib \
                 ./src/main.zig ./src/tls/tlsserver.c -lpq -lssl -lcrypto -lc
 

# Run the built executable
# ./zig-out/bin/app
run:
	./main

# Clean up the built executable
clean:
	rm -f $(OUT)

.PHONY: all build run clean
