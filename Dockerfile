# Use a base image with Flutter pre-installed
FROM instrumentisto/flutter:latest

# Set the working directory inside the container
WORKDIR /app

# Install any additional dependencies (if needed)
RUN apt-get update && apt-get install -y \
  curl \
  git \
  unzip \
  xz-utils \
  zip \
  libglu1-mesa \
  python3

# Verify Flutter installation
RUN flutter doctor

# Copy the Flutter project files into the container
COPY . .

# Build the Flutter web app
RUN flutter build web

# Serve the app using a lightweight HTTP server
EXPOSE 8080
CMD ["python3", "-m", "http.server", "8080", "--directory", "build/web"]