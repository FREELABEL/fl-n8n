FROM n8nio/n8n:1.114.2
USER root
RUN apk add --no-cache git curl postgresql-client
COPY init-n8n.sh /home/node/init-n8n.sh
COPY workflows /home/node/.n8n/workflows
RUN chmod +x /home/node/init-n8n.sh && chown -R node:node /home/node/.n8n
USER node
