# Use official lightweight Python image
FROM python:3.10-slim

# Install system dependencies required by the honeypot and related services
RUN apt-get update && apt-get install -y \
    socat asciinema cron enscript ps2pdf \
    mailutils msmtp figlet lolcat \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN useradd -m honeypotuser
USER honeypotuser

# Set the working directory inside the container
WORKDIR /home/honeypotuser/app

# Copy requirements.txt first to leverage Docker caching
COPY --chown=honeypotuser:honeypotuser requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy all project files to the container
COPY --chown=honeypotuser:honeypotuser . .

# Set up necessary directories and permissions for logs
RUN mkdir -p /home/honeypotuser/honeypot_logs && chmod -R 777 /home/honeypotuser/honeypot_logs

# Expose Flask default port for the web app
EXPOSE 8080

# Set the environment variable for Flask (optional)
ENV FLASK_APP=app.py

# Entrypoint to run everything at once (honeypot.sh and Flask)
CMD bash -c "bash honeypot.sh & python3 app.py"
