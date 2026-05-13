#!/bin/bash
# ==============================================================================
# Neko Void Auto-Deploy & Workflow Trigger
# ==============================================================================
set -e

# 1. Definir mensaje de commit (Usa el texto que le pases, o la fecha actual)
COMMIT_MSG=${1:-"Actualización automática: $(date +'%Y-%m-%d %H:%M:%S')"}

echo "=> [1/3] Preparando archivos locales..."
git add .

echo "=> [2/3] Creando commit: '$COMMIT_MSG'..."
# El || true evita que el script se detenga si no hay cambios nuevos que subir
git commit -m "$COMMIT_MSG" || true 

echo "=> [3/3] Subiendo cambios a GitHub..."
git push origin main # Cambia 'main' por 'master' si esa es tu rama principal

echo "---------------------------------------------------"
echo "✔️ Sincronización de código completada con éxito."
echo "---------------------------------------------------"

# ==============================================================================
# SECCIÓN DE WORKFLOWS (Descomenta lo que necesites)
# ==============================================================================
echo "¿Deseas compilar las ISOs en la nube ahora? (s/n)"
read -r respuesta
if [[ "$respuesta" =~ ^[sS]$ ]]; then
    echo "=> Disparando Workflow..."
    gh workflow run build-iso.yml

    echo "🚀 ¡Workflows iniciados! Revisa la pestaña 'Actions' en GitHub."
else
    echo "🛑 Compilación omitida. Solo se actualizó el código."
fi
