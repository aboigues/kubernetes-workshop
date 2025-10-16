# Installation de Minikube sur AlmaLinux

## Prérequis système
- AlmaLinux 8 ou 9
- 2 CPU minimum
- 2 Go de RAM minimum
- 20 Go d'espace disque
- Accès root ou sudo

## Installation de Docker

```bash
# Mise à jour du système
sudo dnf update -y

# Installation de Docker
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io

# Démarrage de Docker
sudo systemctl start docker
sudo systemctl enable docker

# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER
newgrp docker
```

## Installation de kubectl

```bash
# Téléchargement de kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Installation
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Vérification
kubectl version --client
```

## Installation de Minikube

```bash
# Téléchargement de Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Installation
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Vérification
minikube version
```

## Démarrage de Minikube

```bash
# Démarrer Minikube avec Docker
minikube start --driver=docker --cpus=2 --memory=4096

# Vérification du statut
minikube status

# Configuration de kubectl
kubectl cluster-info
```

## Commandes utiles

```bash
# Arrêter Minikube
minikube stop

# Supprimer le cluster
minikube delete

# Accéder au dashboard
minikube dashboard

# SSH dans le node Minikube
minikube ssh

# Obtenir l'IP de Minikube
minikube ip
```

## Addons utiles

```bash
# Lister les addons disponibles
minikube addons list

# Activer metrics-server
minikube addons enable metrics-server

# Activer ingress
minikube addons enable ingress

# Activer dashboard
minikube addons enable dashboard
```
