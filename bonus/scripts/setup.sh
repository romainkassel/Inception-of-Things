#!/bin/bash

# ************************************************************************** */
# Increase disk size                                                         */
# ************************************************************************** */

#lsblk
#df -h /
#sudo growpart /dev/vda 1
#sudo resize2fs /dev/vda1
#df -h /

# ************************************************************************** */
# Setup Docker Engine                                                        */
# ************************************************************************** */

# Source: official Docker documentation: https://docs.docker.com/engine/install/debian/

# Set up Docker's apt repository.
# Add Docker's official GPG key:
sudo apt-get update -qq
sudo apt-get install ca-certificates curl zsh -y -qq
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update -qq

# Install Docker packages
sudo apt-get install docker.io -y -qq

echo "- - - testing docker installation - - -"
# Verify that Docker is running
sudo systemctl status docker

# Verify that the installation is successful by running the hello-world image
#sudo docker run hello-world

# ************************************************************************** */
# Setup Kubectl                                                              */
# ************************************************************************** */

# Source: official kubernetes documentation: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

# Download the latest release with the command:
sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# ************************************************************************** */
# Setup k3d                                                                  */
# ************************************************************************** */

# Install current latest release of k3d
# Source: official k3d documentation: https://k3d.io/stable/#installation
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Source: official k3d documentation: https://k3d.io/stable/#quick-start

# Create a cluster named mycluster with just a single server node for testing purposes
sudo k3d cluster create mycluster -p "8888:80@loadbalancer"

# Use the new cluster with kubectl, e.g.:
echo "- - - testing kubectl - - -"
file /usr/local/bin/kubectl

echo "- - - testing kubectl nodes - - -"
sudo kubectl get nodes

# Apply all configuration files
sudo kubectl apply -f /vagrant/confs/00-namespaces.yaml

# Check that namespaces have been created
echo "- - - testing kubectl namespace - - -"
sudo kubectl get namespace

# Inspect Events inside dev namespace
sudo kubectl describe pod -l app=playground -n dev

# ************************************************************************** */
# Setup Helm                                                                 */
# ************************************************************************** */

# Installing Helm From Apt (Debian/Ubuntu)
# Source: https://helm.sh/fr/docs/intro/install

sudo apt-get install gpg apt-transport-https --yes -qq
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update -qq
sudo apt-get install helm -qq

# ************************************************************************** */
# Setup Gitlab                                                               */
# ************************************************************************** */

# Downloading official Gitlab repository
helm repo add gitlab https://charts.gitlab.io/

helm repo update

#kubectl create namespace gitlab

# Installing GitLab using Helm and Helm values
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --values /vagrant/confs/01-gitlab.yaml
  #--set global.hosts.domain=example.com \
  #--set global.hosts.externalIP=0.0.0.0 \
  #--set global.edition=ce

# Check that Gitlab pods are running
sudo kubectl get pods -n gitlab

# ************************************************************************** */
# Init Gitlab with default project                                           */
# ************************************************************************** */

sudo kubectl wait --for=condition=available deployment/gitlab-webservice-default -n gitlab --timeout=600s

sudo kubectl exec -it -n gitlab deployment/gitlab-webservice-default -c webservice -- \
/srv/gitlab/bin/rails runner "
  user = User.find_by_username('root');
  organization = Organizations::Organization.first
  project_path = 'root/iot-app-rkassel';

  params = {
    name: 'iot-app-rkassel',
    path: 'iot-app-rkassel',
    namespace: user.namespace,
    creator: user,
    organization: organization,
    visibility_level: Gitlab::VisibilityLevel::PUBLIC
  }
  
  project = Projects::CreateService.new(user, params).execute

  if project.persisted?
    puts 'SUCCESS: Projet iot-app-rkassel créé avec succès.';
  else
    puts 'ERROR: Échec de la création du projet.';
    exit 1;
  end
"

# ************************************************************************** */
# Retrieve and push GitHub public repo into Gitlab project                   */
# ************************************************************************** */

git clone https://github.com/romainkassel/iot-app-rkassel.git
cd iot-app-rkassel
GITLAB_PWD=$(kubectl get secret -n gitlab gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 --decode)
git push http://root:$GITLAB_PWD@gitlab.localhost:8888/root/iot-app-rkassel.git
cd ..

# ************************************************************************** */
# Setup Argo CD                                                              */
# ************************************************************************** */

# Source: official Argo CD documentation: https://argo-cd.readthedocs.io/en/latest/
sudo kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Check that Argo CD pods are running
sudo kubectl get pods -n argocd

echo "- - - applying all confs - - -"
#sudo kubectl apply -f /vagrant/confs

pwd

ls /vagrant/confs/

# Apply Argo CD configuration
sudo kubectl apply -f /vagrant/confs/02-argocd.yaml

# Apply Ingress configuration
sudo kubectl apply -f /vagrant/confs/03-ingress.yaml

# Check that Ingress is active
sudo kubectl get ingress -n dev

# Waiting for Argo CD server to be available
sudo kubectl wait --namespace argocd \
  --for=condition=available deployment/argocd-server \
  --timeout=90s

# Get admin password for Argo CD dashboard
sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Port forwarding to access Argo CD dashboard from host machine browser
#sudo kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8443:443