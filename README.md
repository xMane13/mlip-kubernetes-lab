# Final Term 01: Orchestrating ML Training and Inference with Kubernetes

**Machine Learning in Production (MLOps) — Yachay Tech University**

> End-to-end ML system lifecycle on Kubernetes: continuous training, containerized inference, load balancing, and graceful shutdown via lifecycle hooks.

---

## Repository Structure

```
mlip-kubernetes-lab/
├── model_trainer.py          # Training script (RandomForestRegressor)
├── backend.py                # Flask inference API (/model-info, /predict)
├── Dockerfile.trainer        # Container image for the trainer
├── Dockerfile.backend        # Container image for the backend
├── trainer-deployment.yaml   # Kubernetes CronJob (runs every 2 min)
├── backend-deployment.yaml   # Kubernetes Deployment + NodePort Service
├── persistent-volume.yaml    # PersistentVolumeClaim (shared model storage)
└── demo.sh                   # Live demo script
```

---

## System Architecture

```
CronJob (every 2 min)
        │ triggers
        ▼
  Trainer Pod (model_trainer.py)
        │ writes model.joblib
        ▼
  PersistentVolume (/shared-volume/)
        │ reads (30s reload)       │ reads (30s reload)
        ▼                          ▼
  Backend Pod 1 (Flask)    Backend Pod 2 (Flask)
        │                          │
        └──────────┬───────────────┘
                   ▼
        NodePort Service (port 30081)
                   │ routes requests
                   ▼
              Client (curl)
```

---

## Prerequisites

- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [Docker](https://www.docker.com/) + Docker Hub account
- `kubectl` (bundled with Minikube)

---

## Setup & Deployment

### 1. Start Minikube

```bash
minikube start
kubectl get nodes
```

### 2. Create Shared Volume

```bash
kubectl apply -f persistent-volume.yaml
kubectl get pvc   # wait for STATUS: Bound
```

### 3. Build and Push Docker Images

```bash
export DOCKER_USER=<your-dockerhub-username>

docker build -t $DOCKER_USER/ml-trainer:1.0.0 -f Dockerfile.trainer .
docker push $DOCKER_USER/ml-trainer:1.0.0

docker build -t $DOCKER_USER/ml-backend:1.0.0 -f Dockerfile.backend .
docker push $DOCKER_USER/ml-backend:1.0.0
```

### 4. Update Image Names in YAMLs

Replace `<TU-USUARIO>` with your Docker Hub username:

```bash
sed -i 's/<TU-USUARIO>/<your-dockerhub-username>/g' trainer-deployment.yaml
sed -i 's/<TU-USUARIO>/<your-dockerhub-username>/g' backend-deployment.yaml
```

### 5. Deploy Trainer CronJob

```bash
kubectl apply -f trainer-deployment.yaml
kubectl get cronjobs          # model-trainer-job should appear
kubectl get jobs              # wait ~2 min for first job
kubectl logs <trainer-pod>    # confirm: "Model trained and saved successfully"
```

### 6. Deploy Backend Service

```bash
kubectl apply -f backend-deployment.yaml
kubectl get pods              # 2 flask-backend pods Running
kubectl get svc               # flask-backend-service on port 30081
```

---

## Usage

Get the Minikube IP:

```bash
minikube ip   # e.g. 192.168.49.2
```

**Query model info:**
```bash
curl http://192.168.49.2:30081/model-info
```

**Make a prediction:**
```bash
curl -X POST http://192.168.49.2:30081/predict \
  -H "Content-Type: application/json" \
  -d '{
    "avg_session_duration": 30,
    "visits_per_week": 14,
    "response_rate": 4,
    "feature_usage_depth": 6
  }'
```

**Verify load balancing** (observe `host` field alternating between pods):
```bash
for i in {1..6}; do
  curl -s http://192.168.49.2:30081/model-info | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['host'])"
done
```

---

## Live Demo

```bash
chmod +x demo.sh
./demo.sh
```

The script runs all steps automatically: cluster check → CronJob → trainer logs → backend pods → service → model-info → prediction → load balancing.

---

## Graceful Shutdown (preStop Hook)

The `preStop` lifecycle hook in `backend-deployment.yaml` sends `SIGUSR1` to the Flask process before Kubernetes delivers `SIGTERM`, allowing in-flight requests to complete.

To demonstrate:

```bash
# Terminal 1 — watch logs
kubectl logs -l app=flask-backend -f

# Terminal 2 — trigger rollout
kubectl rollout restart deployment/flask-backend-deployment
```

Expected log sequence:
```
preStop signal received (SIGUSR1). Host preparing for shutdown: flask-backend-...
SIGTERM received. Host being terminated: flask-backend-...
```

---

## Key Design Decisions

| Concern | Solution |
|---|---|
| Shared model storage | PersistentVolumeClaim mounted by both trainer and backend |
| Continuous retraining | Kubernetes CronJob (every 2 min) |
| Zero-downtime model updates | Background thread reloads model every 30s |
| Load balancing | NodePort Service with 2 backend replicas |
| Graceful shutdown | preStop hook sends SIGUSR1 before SIGTERM |

---

## Reference

- [mlip-cmu/mlip-kubernetes-lab](https://github.com/mlip-cmu/mlip-kubernetes-lab)
- [Kubernetes Services Networking](https://kubernetes.io/docs/concepts/services-networking/)
- [Container Lifecycle Hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/)
