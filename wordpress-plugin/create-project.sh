#!/usr/bin/env bash
#
# create-project.sh
# ------------------
# Équivalent d'un "composer create-project" basé sur ce dépôt Git, pour un
# plugin WordPress.
#
# Ce script :
#   1. Clone le squelette WordPress Plugin dans un nouveau dossier
#   2. Supprime l'historique Git du squelette (départ propre)
#   3. Remplace PLUGIN_NAME dans docker-compose.yml par le slug du plugin
#      (déduit du répertoire de destination)
#   4. Démarre les conteneurs Docker (build inclus)
#
# Usage :
#   ./create-project.sh [repertoire-destination] [url-du-depot-git]
#
# Le répertoire de destination peut être passé en argument ou saisi de manière
# interactive (par défaut : le répertoire courant "."). Il sert également à
# déterminer le slug du plugin (wp-content/plugins/<slug>).
#
# Exemple :
#   ./create-project.sh                 # demande le répertoire (défaut : .)
#   ./create-project.sh mon-plugin
#   ./create-project.sh mon-plugin https://github.com/GBonnaire/skeleton-wordpress-plugin.git

set -euo pipefail

# --- Paramètres -------------------------------------------------------------
DEFAULT_REPO="https://github.com/GBonnaire/skeleton-wordpress-plugin.git"

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

# --- 2Bis. Suppression des fichiers du skeleton -----------------------------
rm -f README.md

# --- 3. Détermination du slug du plugin & mise à jour de docker-compose.yml -
if [ "$DEST" = "." ]; then
  RAW_NAME="$(basename "$(pwd)")"
else
  RAW_NAME="$(basename "$DEST")"
fi

# Slugification : minuscules, caractères non alphanumériques -> "-"
PLUGIN_SLUG="$(echo "$RAW_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
PLUGIN_SLUG="${PLUGIN_SLUG:-my-plugin}"

echo "==> Remplacement de PLUGIN_NAME par '$PLUGIN_SLUG' dans docker-compose.yml ..."
sed -i.bak "s/PLUGIN_NAME/$PLUGIN_SLUG/g" docker-compose.yml
rm -f docker-compose.yml.bak

# --- 4. Démarrage de Docker --------------------------------------------------
echo "==> Construction et démarrage des conteneurs Docker ..."
$DC up -d --build

# Attendre que le conteneur claudeai réponde
echo "==> Attente de la disponibilité du conteneur claudeai ..."
for i in $(seq 1 30); do
  if $DC exec -T claudeai php -v >/dev/null 2>&1; then
    break
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then
    echo "Erreur : le conteneur claudeai n'est pas prêt après 60s." >&2
    exit 1
  fi
done

echo ""
echo "✅ Projet initialisé avec succès dans '$DEST' (plugin : $PLUGIN_SLUG)."
echo "   - WordPress        : http://localhost"
echo "   - PhpMyAdmin       : http://localhost:8080"
echo "   - MailDev          : http://localhost:8081"
echo ""
echo "   ➜ Terminez l'installation de WordPress sur http://localhost, activez"
echo "     le plugin '$PLUGIN_SLUG' depuis Extensions, puis lancez le skill"
echo "     Claude Code /init-skeleton depuis le conteneur claudeai :"
echo "       $DC exec claudeai bash"
