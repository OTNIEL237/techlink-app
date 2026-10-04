# Utilisation d'une image de base légère et sécurisée
FROM node:20-alpine

# Méta-données
LABEL maintainer="TechLink Team"
LABEL description="TechLink Backend API"

# Définition du répertoire de travail dans le conteneur
WORKDIR /usr/src/app

# Copie des fichiers de configuration NPM
COPY package*.json ./

# Installation des dépendances (uniquement pour la production)
# L'utilisation de 'ci' garantit des builds propres et reproductibles
RUN npm ci --only=production

# Copie du reste du code source
COPY . .

# Définir l'environnement en production par défaut
ENV NODE_ENV=production
ENV PORT=3000

# Exposer le port sur lequel l'API va écouter
EXPOSE 3000

# Lancement de l'application
CMD ["node", "src/app.js"]
