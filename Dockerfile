FROM nginx:1.21.1

LABEL maintainer="alphonsine"

# Mise à jour minimale de sécurité
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Nettoyage du répertoire par défaut d'Nginx
RUN rm -rf /usr/share/nginx/html/*

# Copie le code du site 
COPY . /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
