#!/bin/bash

# Script de nettoyage de l'environnement

echo "=== Nettoyage de l'environnement ==="

# Suppression de toutes les ressources dans le namespace default
echo "Suppression des ressources dans default..."
kubectl delete all --all 2>/dev/null || true

# Suppression des ConfigMaps et Secrets
kubectl delete configmap --all 2>/dev/null || true
kubectl delete secret --all 2>/dev/null || true

# Suppression des PVC et PV
kubectl delete pvc --all 2>/dev/null || true
kubectl delete pv --all 2>/dev/null || true

# Suppression des Ingress
kubectl delete ingress --all 2>/dev/null || true

# Suppression des namespaces de formation
for ns in dev staging production; do
    kubectl delete namespace $ns 2>/dev/null || true
done

echo "Nettoyage terminé"
