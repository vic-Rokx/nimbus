# Use an official Zig runtime as a parent image
FROM ziglang/zig:0.13.0 

# Set the working directory inside the container
WORKDIR /app

# Copy the rest of the application to the working directory
COPY . .

# Build the zig bin
RUN zig build

# Use lightweight alpine
FROM alpine:latest

# Install libraries if neccersary
# RUN apk add --no-cache libstdc++

# Expose the port that your Fastify app runs on
EXPOSE 8080

# Command to run the application using yarn
CMD ["./zig-out/bin/app"]
