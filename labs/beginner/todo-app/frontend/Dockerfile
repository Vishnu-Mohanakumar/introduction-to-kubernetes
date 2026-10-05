FROM nginx:alpine

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy static files
COPY index.html /usr/share/nginx/html/

# nginx's master process needs to run as root to manage /run/nginx.pid - don't add USER nginx
# here, it causes CrashLoopBackOff (see lab-solution/main/TROUBLESHOOTING_AND_ERRORS.md)

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]