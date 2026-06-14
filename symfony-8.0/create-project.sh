#!/usr/bin/env bash
#
# create-project.sh
# ------------------
# Équivalent d'un "composer create-project" basé sur ce dépôt Git.
#
# Ce script :
#   1. Clone le squelette Symfony 8.0 dans un nouveau dossier
#   2. Supprime l'historique Git du squelette (départ propre)
#   3. Démarre les conteneurs Docker (build inclus)
#   4. Lance, dans le conteneur PHP : composer install, yarn install, yarn dev
#
# Usage :
#   ./scripts/create-project.sh [repertoire-destination] [url-du-depot-git]
#
# Le répertoire de destination peut être passé en argument ou saisi de manière
# interactive (par défaut : le répertoire courant ".").
#
# Exemple :
#   ./scripts/create-project.sh                 # demande le répertoire (défaut : .)
#   ./scripts/create-project.sh mon-app
#   ./scripts/create-project.sh mon-app https://github.com/GBonnaire/skeleton-symfony-8.0.git

set -euo pipefail

# --- Paramètres -------------------------------------------------------------
DEFAULT_REPO="https://github.com/GBonnaire/skeleton-symfony-8.0.git"

DEST="${1:-}"
REPO_URL="${2:-$DEFAULT_REPO}"

# Demande interactive du répertoire de destination si non fourni en argument
if [ -z "$DEST" ]; then
  read -r -p "Répertoire de destination [.] : " DEST
  DEST="${DEST:-.}"
fi

# Validation du répertoire de destination
if [ "$DEST" = "." ]; then
  # Clonage dans le répertoire courant : il doit être vide
  if [ -n "$(ls -A . 2>/dev/null)" ]; then
    echo "Erreur : le répertoire courant n'est pas vide, impossible d'y cloner le projet." >&2
    exit 1
  fi
elif [ -e "$DEST" ]; then
  echo "Erreur : le dossier '$DEST' existe déjà." >&2
  exit 1
fi

# --- Détection de la commande Docker Compose --------------------------------
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"
else
  echo "Erreur : Docker Compose est introuvable. Installez Docker Desktop ou docker-compose." >&2
  exit 1
fi

# --- 1. Clonage -------------------------------------------------------------
echo "==> Clonage de $REPO_URL dans '$DEST' ..."
git clone "$REPO_URL" "$DEST"

cd "$DEST"

# --- 2. Réinitialisation de l'historique Git --------------------------------
echo "==> Suppression de l'historique Git du squelette ..."
rm -rf .git
git init -q
echo "    Nouveau dépôt Git initialisé."

# --- 3. Démarrage de Docker -------------------------------------------------
echo "==> Construction et démarrage des conteneurs Docker ..."
$DC up -d --build

# Attendre que le conteneur PHP réponde
echo "==> Attente de la disponibilité du conteneur PHP ..."
for i in $(seq 1 30); do
  if $DC exec -T php php -v >/dev/null 2>&1; then
    break
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then
    echo "Erreur : le conteneur PHP n'est pas prêt après 60s." >&2
    exit 1
  fi
done

# --- 4. Installation des dépendances ----------------------------------------
echo "==> composer install ..."
$DC exec -T php composer install

echo "==> yarn install ..."
$DC exec -T php yarn install

echo "==> yarn dev ..."
$DC exec -T php yarn dev

echo ""
echo "✅ Projet initialisé avec succès dans '$DEST'."
echo "   - Application      : http://localhost"
echo "   - PhpMyAdmin       : http://localhost:8080"
echo "   - MailDev          : http://localhost:8081"
