#!/usr/bin/env bash

# Sets up a multi-cluster Istio lab with one primary and two remotes.
#
# Loosely adapted from:
#   https://istio.io/v1.15/docs/setup/install/multicluster/primary-remote/
#   https://github.com/istio/common-files/blob/release-1.15/files/common/scripts/kind_provisioner.sh

set -eu
set -o pipefail

source "${BASH_SOURCE[0]%/*}"/lib/logging.sh
source "${BASH_SOURCE[0]%/*}"/lib/kind.sh
source "${BASH_SOURCE[0]%/*}"/lib/metallb.sh


# ---- Definitions: clusters ----

declare -A cluster_central=(
  [name]=lgtm-central
  [pod_subnet]=10.10.0.0/16
  [svc_subnet]=10.255.10.0/24
  [metallb_l2pool_start]=10
)

declare -A cluster_remote=(
  [name]=lgtm-remote
  [pod_subnet]=10.20.0.0/16
  [svc_subnet]=10.255.20.0/24
  [metallb_l2pool_start]=30
)

#--------------------------------------

# Create clusters

log::msg "Creating KinD clusters"

kind::cluster::create ${cluster_central[name]} ${cluster_central[pod_subnet]} ${cluster_central[svc_subnet]} &
kind::cluster::create ${cluster_remote[name]}  ${cluster_remote[pod_subnet]}  ${cluster_remote[svc_subnet]} &
wait

kind::cluster::wait_ready ${cluster_central[name]}
kind::cluster::wait_ready ${cluster_remote[name]}

# Add cross-cluster routes

declare central_cidr
declare remote_cidr
central_cidr=$(kind::cluster::pod_cidr ${cluster_central[name]})
remote_cidr=$(kind::cluster::pod_cidr  ${cluster_remote[name]})

declare central_ip
declare remote_ip
central_ip=$(kind::cluster::node_ip ${cluster_central[name]})
remote_ip=$(kind::cluster::node_ip  ${cluster_remote[name]})

log::msg "Adding routes to other clusters"

kind::cluster::add_route ${cluster_central[name]} ${remote_cidr}  ${remote_ip}

kind::cluster::add_route ${cluster_remote[name]}  ${central_cidr} ${central_ip}


# Deploy MetalLB

log::msg "Deploying MetalLB inside clusters"

metallb::deploy ${cluster_central[name]} ${cluster_central[metallb_l2pool_start]}
metallb::deploy ${cluster_remote[name]} ${cluster_remote[metallb_l2pool_start]}

