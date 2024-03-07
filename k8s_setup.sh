#!/usr/bin/env bash

kubeconfig="./.vagrant/provisioners/ansible/inventory/artifacts/admin.conf"

function check_is_kubeconfig_exist() {
  if ! [[ -f "${kubeconfig}" ]]; then
    echo "Fatal! There is no .vagrant/provisioners/ansible/inventory/artifacts/admin.conf in ${PWD}. Exit." >&2; exit 1;
  fi
}

function add_and_update_helm_repos() {
  helm --kubeconfig "${kubeconfig}" repo add argo https://argoproj.github.io/argo-helm;
  helm --kubeconfig "${kubeconfig}" repo add jetstack https://charts.jetstack.io;
  helm --kubeconfig "${kubeconfig}" repo add istio https://istio-release.storage.googleapis.com/charts;
  helm --kubeconfig "${kubeconfig}" repo update argo jetstack istio;
}

function upgrade_install_kube_vip() {
  kubectl --kubeconfig "${kubeconfig}" apply -f \
    https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/v0.0.4/manifest/kube-vip-cloud-controller.yaml;
  kubectl --kubeconfig "${kubeconfig}" \
    -n kube-system create cm kubevip --from-literal cidr-global=192.168.121.248/30
}

function upgrade_install_cert_manager() {
  helm --kubeconfig "${kubeconfig}" \
  upgrade -i cert-manager --create-namespace \
  --namespace cert-manager --version v1.14.3 \
  jetstack/cert-manager --set installCRDs=true
}

function upgrade_install_istio() {
  helm --kubeconfig "${kubeconfig}" upgrade -i istio-base \
    istio/base -n istio-system --create-namespace || { echo "Failure of Istio-base installation. Aborting."; exit 1; }
  helm --kubeconfig "${kubeconfig}" upgrade -i istiod \
    istio/istiod -n istio-system || { echo "Failure of Istiod installation. Aborting."; exit 1; }
  helm --kubeconfig "${kubeconfig}" upgrade -i istio-ingressgateway \
    istio/gateway -n istio-system  || { echo "Failure of Istio-ingressgateway installation. Aborting."; exit 1; }
}

function upgrade_install_argocd() {
  helm --kubeconfig "${kubeconfig}" upgrade \
    -i argocd argo/argo-cd --wait \
    --create-namespace -n argocd \
    -f ./infra/values/argocd/argocd.yaml \
    --version=6.2.3 || { echo "Failure of ArgoCD installation. Aborting."; exit 1; }
}

function apply_k8s_manifests() {
  kubectl --kubeconfig "${kubeconfig}" \
    apply -f infra/templates/selfsigned-issuer.yaml;
  kubectl --kubeconfig "${kubeconfig}" \
    apply -f infra/templates/home.lab.yaml;
  kubectl --kubeconfig "${kubeconfig}" \
    apply -f infra/templates/gateway.yaml;
  kubectl --kubeconfig "${kubeconfig}" \
    apply -f infra/templates/argocd-vs.yaml
}

function main() {
    check_is_kubeconfig_exist
    upgrade_install_kube_vip
    add_and_update_helm_repos
    upgrade_install_cert_manager
    upgrade_install_istio
    upgrade_install_argocd
    apply_k8s_manifests
}

main
