#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Error en la linea $LINENO. Saliendo..."; exit 1' ERR

command -v git >/dev/null || {
  echo "git no esta instalado"
  exit 1
}

if [ -d .git ] && git remote get-url origin >/dev/null 2>&1; then
  #Repositorio ya subido: solo actualizar
  echo "Repositorio existente: $(git remote get-url origin)"
  read -rp "Mensaje del commit (Enter = automatico): " MSG
  MSG=${MSG:-"Actualizcion $(date '+%Y-%m-%d %H:%M')"}
  git add -A
  if git diff --cached --quiet; then
    echo "No hay cambios que subir."
  else
    git commit -m "$MSG"
  fi
  git push -u origin "$(git branch --show-current)"
else
  #No hay repositorio: crear desde 0
  command -v gh >/dev/null || {
    echo "Necesitas GitHub CLI (gh) y haber ejecutado: gh auth login"
    exit 1
  }
  gh auth status >/dev/null
  read -rp "Nombre del repositorio: " REPO
  [ -n "$REPO" ] || {
    echo "El nombre del repositorio es obligatorio"
    exit 1
  }
  read -rp "Mensaje del commit (Enter = 'Primer commit'): " MSG
  MSG=${MSG:-"Primer commit"}
  [ -d .git ] || git init -b main
  git add -A
  git diff --cached --quiet || git commit -m "$MSG"
  OWNER=$(gh api user -q .login)
  if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
    #El repo ya existe en GitHub: solo conectarlo y subir
    echo "El repo $OWNER/$REPO ya existe en GitHub, conectando..."
    URL="https://github.com/$OWNER/$REPO.git"
    git remote add origin "$URL" 2>/dev/null || git remote set-url origin "$URL"
    git push -u origin "$(git branch --show-current)"
  elif ! gh repo create "$REPO" --private --source=. --remote=origin --push; then
    #Si la creacion falla (p. ej. el nombre ya existe), conectar el repo existente y subir
    echo "No se pudo crear el repo, intentando conectar con el existente..."
    URL="https://github.com/$OWNER/$REPO.git"
    git remote add origin "$URL" 2>/dev/null || git remote set-url origin "$URL"
    git push -u origin "$(git branch --show-current)"
  fi
fi

echo "Listo"
