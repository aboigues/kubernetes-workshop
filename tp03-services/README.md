# TP03 - Services et exposition

## Objectifs
- Comprendre les différents types de Services
- Exposer des applications
- Tester la communication inter-pods

## Exercice 1 - Service ClusterIP
Créez un Service ClusterIP pour votre Deployment nginx.

Consignes :
1. Créez `manifests/nginx-service-clusterip.yaml`
2. Type : ClusterIP
3. Port : 80
4. Sélecteur : app=nginx

Testez avec :
```bash
kubectl run test-pod --image=busybox -it --rm -- wget -qO- nginx-service
```

## Exercice 2 - Service NodePort
Créez un Service NodePort.

Consignes :
1. Créez `manifests/nginx-service-nodeport.yaml`
2. Type : NodePort
3. Port : 80
4. NodePort : 30080

Accédez via : `http://<minikube-ip>:30080`

## Exercice 3 - Application multi-tiers
Déployez une application frontend et backend avec leurs Services.
