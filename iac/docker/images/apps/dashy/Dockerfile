# Official Dashy image as the base
FROM lissy93/dashy:latest

# Copy the dashboard config into the image
COPY config.yml /app/user-data/conf.yml

# Copy the launcher script
COPY script.sh /opt/dashy/script.sh

# Port used by the dashboard
EXPOSE 4000

# Make the launcher executable
RUN chmod +x /opt/dashy/script.sh

# Start Dashy via the launcher
ENTRYPOINT ["/opt/dashy/script.sh"]
