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
  helm --kubeconfig "${kubeconfig}" repo add metallb https://metallb.github.io/metallb;
  helm --kubeconfig "${kubeconfig}" repo update argo jetstack istio;
}

function upgrade_install_metallb() {
  echo "Installing metallb. Please wait...";
  helm --kubeconfig "${kubeconfig}" \
  upgrade -i metallb --create-namespace \
  --namespace metallb-system --version 0.14.3 \
  metallb/metallb
}

function upgrade_install_cert_manager() {
  echo "Installing cert-manager. Please wait...";
  helm --kubeconfig "${kubeconfig}" \
  upgrade -i cert-manager --create-namespace \
  --namespace cert-manager --version v1.14.3 \
  jetstack/cert-manager --set installCRDs=true
}

function upgrade_install_istio() {
  echo "Installing istio components. Please wait...";
  helm --kubeconfig "${kubeconfig}" upgrade -i istio-base \
    istio/base -n istio-system --create-namespace --version 1.20.3 || \
    { echo "Failure of istio-base installation. Aborting."; exit 1; }
  helm --kubeconfig "${kubeconfig}" upgrade -i istiod \
    istio/istiod -n istio-system --version 1.20.3 || \
    { echo "Failure of Istiod installation. Aborting."; exit 1; }
  helm --kubeconfig "${kubeconfig}" upgrade -i istio-ingressgateway \
    istio/gateway -n istio-system --version 1.20.3 || \
    { echo "Failure of istio-ingressgateway installation. Aborting."; exit 1; }
}

function upgrade_install_argocd() {
  echo "Installing argocd. Please wait...";
  helm --kubeconfig "${kubeconfig}" upgrade \
    -i argocd argo/argo-cd --wait \
    --create-namespace -n argocd \
    -f ./infra/values/argocd/argocd.yaml \
    --version 6.6.0 || { echo "Failure of argocd installation. Aborting."; exit 1; }
}

function apply_k8s_manifests() {
  kubectl --kubeconfig "${kubeconfig}" \
    apply -f infra/templates/selfsigned-issuer.yaml;
  kubectl --kubeconfig "${kubeconfig}" \
    apply -f infra/templates/home.lab.yaml;
  kubectl --kubeconfig "${kubeconfig}" \
    apply -f infra/templates/gateway.yaml;
  kubectl --kubeconfig "${kubeconfig}" \
    apply -f infra/templates/argocd-vs.yaml; \
  kubectl --kubeconfig "${kubeconfig}" \
      apply -f infra/templates/IPAddressPool.yaml; \
  kubectl --kubeconfig "${kubeconfig}" \
      apply -f infra/templates/L2Advertisement.yaml;
}

function main() {
    check_is_kubeconfig_exist
    upgrade_install_metallb
    add_and_update_helm_repos
    upgrade_install_cert_manager
    upgrade_install_istio
    upgrade_install_argocd
    apply_k8s_manifests
}

main
