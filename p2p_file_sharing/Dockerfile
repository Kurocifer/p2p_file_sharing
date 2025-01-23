# Use the Windows Flutter Docker image
FROM cirrusci/flutter:stable

# Enable Windows cross-compilation
RUN apt-get update && apt-get install -y \
    mingw-w64-x86-64 \
    cmake \
    ninja-build

# Set the working directory
WORKDIR /app

# Copy the Flutter project files into the container
COPY . .

# Install Flutter dependencies
RUN flutter pub get

# Build the Flutter app for Windows
RUN flutter build windows --release

# The build artifacts will be in /app/build/windows/runner/Release
