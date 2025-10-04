FROM n8nio/n8n:1.114.2                                  
USER root                                            
RUN apt-get update && apt-get install -y git curl \   
&& rm -rf /var/lib/apt/lists/*  
USER node  

CMD ["n8n", "start", "--host=0.0.0.0", "--port", "5678"]  
