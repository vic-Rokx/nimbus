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
	$(ZIG) build-exe ./src/main.zig -I/opt/homebrew/opt/libpq/include -L/opt/homebrew/opt/libpq/lib -lpq
 

# Run the built executable
run:
	./zig-out/bin/app

# Clean up the built executable
clean:
	rm -f $(OUT)

.PHONY: all build run clean
