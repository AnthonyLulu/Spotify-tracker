FROM node:20-alpine

WORKDIR /app

# pnpm via corepack
RUN corepack enable

# Copie juste ce qu'il faut pour installer
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

# Copie les package.json des workspaces pour que pnpm resolve bien
COPY apps/api/package.json apps/api/package.json

# Install deps (workspace)
RUN pnpm install

# Copie le code
COPY . .

# Expose API
EXPOSE 3001

# Dev command (tsx watch)
CMD ["pnpm", "--filter", "api", "dev"]
