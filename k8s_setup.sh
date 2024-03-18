#!/usr/bin/env bash

# For using this script, you must pass arg with counter name.
# Example: ./k8s_setup.sh home-lab

kubeconfig="./.vagrant/provisioners/ansible/inventory/artifacts/admin.conf"
shell_arg=$1

function check_is_args_passed() {
  if [[ $# -ne 1 ]]; then
      echo "Fatal! There is no arg passed args. Exit." >&2
      exit 2
  fi
}

# This function calling with one arg, which contain application name
function get_application_version() {
  local application_name
  local version
  application_name=$1
  version=$(yq eval ".applications.[] | select(.name == \"$application_name\") .targetRevision" "./infra/${shell_arg}-values.yaml")

  if [[ "${version}" == "" ]]; then
    echo "Fatal! There is no version for $application_name application in infra/${shell_arg}-values.yaml. Exit." >&2
    exit 1
  else
    echo "${version}"
  fi
}

# Check is the "yq" "kubectl" "helm" already installed on host
function check_is_cli_tools_installed() {
  components_array=("yq" "kubectl" "helm")
  for i in "${components_array[@]}"; do
    command -v "${i}" >/dev/null 2>&1 ||
      {
        echo "${i} is required, but it's not installed. Aborting." >&2
        exit 1
      }
  done
}

# <shell_arg>-values.yaml is single source of truth for helm installation. The file must be exist.
function check_is_values_file_exist() {
  if ! [[ -f "./infra/${shell_arg}-values.yaml" ]]; then
    echo "Fatal! There is no values file in ${PWD}/infra. Exit." >&2
    exit 1
  fi
}

# admin.conf like ~/.kube/config file. Must be appear after kubespray successfully running.
function check_is_kubeconfig_exist() {
  if ! [[ -f "${kubeconfig}" ]]; then
    echo "Fatal! There is no .vagrant/provisioners/ansible/inventory/artifacts/admin.conf in ${PWD}. Exit." >&2
    exit 1
  fi
}

function add_and_update_helm_repos() {
  helm --kubeconfig "${kubeconfig}" repo add argo https://argoproj.github.io/argo-helm
  helm --kubeconfig "${kubeconfig}" repo add jetstack https://charts.jetstack.io
  helm --kubeconfig "${kubeconfig}" repo add istio https://istio-release.storage.googleapis.com/charts
  helm --kubeconfig "${kubeconfig}" repo add metallb https://metallb.github.io/metallb
  helm --kubeconfig "${kubeconfig}" repo update argo jetstack istio
}

# Metallb app allow you using service aka loadBalancer with ip in the same network in L2 mode
function upgrade_install_metallb() {
  echo "Installing metallb. Please wait..."
  helm --kubeconfig "${kubeconfig}" \
    upgrade --install metallb --create-namespace \
    --namespace metallb-system --version "$(get_application_version 'metallb')" \
    metallb/metallb
}

# Cert-manager needs for self-signed certs for istio service mesh
function upgrade_install_cert_manager() {
  echo "Installing cert-manager. Please wait..."
  helm --kubeconfig "${kubeconfig}" \
    upgrade --install cert-manager --create-namespace \
    jetstack/cert-manager -f ./infra/values/cert-manager/cert-manager.yaml \
    --namespace cert-manager --version "$(get_application_version 'cert-manager')" ||
    {
      echo "Failure of argocd installation. Aborting."
      exit 1
    }
}

# Istio allow you create service mesh and with specific entrypoint
function upgrade_install_istio() {
  echo "Installing istio components. Please wait..."
  helm --kubeconfig "${kubeconfig}" upgrade --install istio-base \
    istio/base -n istio-system --create-namespace --version "$(get_application_version 'istio-base')" ||
    {
      echo "Failure of istio-base installation. Aborting."
      exit 1
    }
  helm --kubeconfig "${kubeconfig}" upgrade --install istiod \
    istio/istiod -n istio-system --version "$(get_application_version 'istiod')" ||
    {
      echo "Failure of Istiod installation. Aborting."
      exit 1
    }
  helm --kubeconfig "${kubeconfig}" upgrade --install istio-ingressgateway \
    istio/gateway -n istio-system --version 1.20.3 ||
    {
      echo "Failure of istio-ingressgateway installation. Aborting."
      exit 1
    }
}

# ArgoCD control of installations in k8s cluster
function upgrade_install_argocd() {
  echo "Installing argocd. Please wait..."
  helm --kubeconfig "${kubeconfig}" upgrade \
    --install argocd argo/argo-cd --wait \
    --create-namespace -n argocd \
    -f ./infra/values/argocd/argocd.yaml \
    --version "$(get_application_version 'argocd')" || {
    echo "Failure of argocd installation. Aborting."
    exit 1
  }
}

# There is some extra manifest, which needs to apply for correct work istio, metallb and cert-manager apps
function apply_extra_manifests() {
  echo "Apply extra manifests. Please wait..."
  helm template --show-only templates/extra-manifests.yaml extras ./infra \
    -f "./infra/${shell_arg}-values.yaml" | kubectl --kubeconfig "${kubeconfig}" apply -f -
}

function main() {
  check_is_args_passed $shell_arg
  check_is_cli_tools_installed
  check_is_values_file_exist
  check_is_kubeconfig_exist
  upgrade_install_metallb
  add_and_update_helm_repos
  upgrade_install_cert_manager
  upgrade_install_istio
  upgrade_install_argocd
  apply_extra_manifests
}

main
