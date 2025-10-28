FROM n8nio/n8n:1.114.2
USER root
RUN apk add --no-cache git curl
USER node  
