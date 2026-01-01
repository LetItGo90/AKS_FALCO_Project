# Kubernetes Threat Detection Lab - Ansible Automation

## Prerequisites
- Azure CLI authenticated
- kubectl configured for your AKS cluster
- Ansible installed with required collections

## Install Dependencies
`bash
ansible-galaxy collection install -r requirements.yml
`

## Run Playbook
`bash
ansible-playbook deploy-falco.yml
`

## What This Deploys
1. Azure Log Analytics workspace for SIEM integration
2. Falco runtime security with custom detection rules
3. Container Insights for log collection
4. Falcosidekick for alert forwarding
