#!/bin/bash
# ============================================================
export PATH=$PATH:/home/moon/.minikube/cache/linux/amd64/v1.35.1
# MLIP Kubernetes Lab — Demo Script
# ============================================================

sed -i '2a export PATH=$PATH:/home/moon/.minikube/cache/linux/amd64/v1.35.1' demo.sh
IP="192.168.49.2"
PORT="30081"

echo "=================================================="
echo "   MLIP Kubernetes Lab - Live Demo"
echo "=================================================="

# ----------------------------------------------------------
echo ""
echo ">>> PASO 1: Verificar cluster"
echo "----------------------------------------------------------"
kubectl get nodes
echo ""

# ----------------------------------------------------------
echo ">>> PASO 2: Verificar CronJob de entrenamiento"
echo "----------------------------------------------------------"
kubectl get cronjobs
echo ""

# ----------------------------------------------------------
echo ">>> PASO 3: Ver jobs de entrenamiento ejecutados"
echo "----------------------------------------------------------"
kubectl get pods | grep trainer
echo ""

# ----------------------------------------------------------
echo ">>> PASO 4: Logs del último job de entrenamiento"
echo "----------------------------------------------------------"
LAST_POD=$(kubectl get pods --no-headers | grep trainer | tail -1 | awk '{print $1}')
kubectl logs $LAST_POD
echo ""

# ----------------------------------------------------------
echo ">>> PASO 5: Verificar pods del backend (2 réplicas)"
echo "----------------------------------------------------------"
kubectl get pods | grep flask
echo ""

# ----------------------------------------------------------
echo ">>> PASO 6: Verificar servicio"
echo "----------------------------------------------------------"
kubectl get svc flask-backend-service
echo ""

# ----------------------------------------------------------
echo ">>> PASO 7: Consultar info del modelo"
echo "----------------------------------------------------------"
curl -s http://$IP:$PORT/model-info | python3 -m json.tool
echo ""

# ----------------------------------------------------------
echo ">>> PASO 8: Hacer predicción de engagement"
echo "----------------------------------------------------------"
curl -s -X POST http://$IP:$PORT/predict \
  -H "Content-Type: application/json" \
  -d '{
    "avg_session_duration": 30,
    "visits_per_week": 14,
    "response_rate": 4,
    "feature_usage_depth": 6
  }' | python3 -m json.tool
echo ""

# ----------------------------------------------------------
echo ">>> PASO 9: Load balancing — 6 requests distribuidos entre réplicas"
echo "----------------------------------------------------------"
for i in {1..6}; do
  HOST=$(curl -s http://$IP:$PORT/model-info | python3 -c "import sys,json; print(json.load(sys.stdin)['host'])")
  echo "  Request $i → $HOST"
done
echo ""

echo "=================================================="
echo "   Demo completado exitosamente ✓"
echo "=================================================="
