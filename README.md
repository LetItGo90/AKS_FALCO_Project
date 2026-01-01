# 🛡️ Kubernetes Threat Detection Lab

Real-time security monitoring for Kubernetes using **Falco** and **Azure Log Analytics**. This project demonstrates how to detect and alert on suspicious container behavior in a production-like environment.

![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoftazure&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)
![Falco](https://img.shields.io/badge/Falco-00AEC7?style=flat&logo=falco&logoColor=white)

---

## 📋 Overview

I built this lab to explore runtime security in Kubernetes. The goal: detect threats like unauthorized shell access or sensitive file reads, and forward those alerts to Azure for centralized monitoring.

**What it does:**
- Monitors all container activity at the syscall level using Falco
- Detects suspicious behavior (shell spawns, file access, privilege escalation)
- Streams alerts to Azure Log Analytics for querying and alerting
- Sends email notifications on critical security events

---

## 🏗️ Architecture

┌──────────────────────────────────────────────────────────────────────┐
│ AKS Cluster │
│ │
│ ┌──────────────────┐ ┌──────────────────┐ │
│ │ Sample App │ │ Falco │ │
│ │ ┌────────────┐ │ │ (DaemonSet) │ │
│ │ │ Frontend │ │ │ │ │ │
│ │ ├────────────┤ │ │ eBPF Driver │ │
│ │ │ Backend │ │ │ │ │ │
│ │ ├────────────┤ │ │ JSON Alerts │ │
│ │ │ MongoDB │ │ └────────┬─────────┘ │
│ │ └────────────┘ │ │ │
│ └──────────────────┘ │ │
│ │ │
│ ┌──────────────────────────────────┴───────────────────────────┐ │
│ │ Container Insights │ │
│ │ (ama-logs) │ │
│ └──────────────────────────────────┬───────────────────────────┘ │
└──────────────────────────────────────┼───────────────────────────────┘
│
▼
┌──────────────────────────────────┐
│ Azure Log Analytics │
│ (falco-logs) │
│ │
│ ┌────────────────────────────┐ │
│ │ KQL Threat Hunting │ │
│ └────────────────────────────┘ │
│ ┌────────────────────────────┐ │
│ │ Alert Rules │ │
│ └─────────────┬──────────────┘ │
└─────────────────┼────────────────┘
│
▼
📧 Email Alerts
yaml


---

## 🚨 Detection Rules

### Built-in Falco Rules
Falco ships with hundreds of rules out of the box, including:
- Container drift detection
- Privilege escalation attempts
- Cryptomining indicators
- Reverse shell detection

### Custom Rules I Added

**Shell Activity in Container**
```yaml
- rule: Shell Activity in Container
  desc: Detect shell activity within a container
  condition: spawned_process and container and proc.name in (bash, sh, zsh, ash)
  output: "Shell spawned in container (user=%user.name command=%proc.cmdline container=%container.name)"
  priority: WARNING

Sensitive File Access
yaml

- rule: Sensitive File Access
  desc: Detect access to sensitive files
  condition: open_read and container and fd.name in (/etc/shadow, /etc/passwd, /etc/sudoers)
  output: "Sensitive file accessed (user=%user.name file=%fd.name container=%container.name)"
  priority: WARNING

🔍 Querying Alerts

Once alerts flow into Log Analytics, you can hunt for threats with KQL:

Recent Security Events
kql

ContainerLogV2 
| where PodNamespace == "falco" 
| where ContainerName == "falco" 
| extend Alert = parse_json(LogMessage)
| where Alert.priority in ("Warning", "Critical", "Error")
| project TimeGenerated, Priority=Alert.priority, Rule=Alert.rule, Output=Alert.output
| order by TimeGenerated desc

Shell Spawns in Last 24 Hours
kql

ContainerLogV2 
| where TimeGenerated > ago(24h)
| where PodNamespace == "falco"
| where LogMessage contains "shell" or LogMessage contains "bash"
| project TimeGenerated, LogMessage

🧪 Testing Detection

Trigger some alerts to verify everything works:
bash

# Spawn a shell (triggers shell detection)
kubectl run test --image=alpine --rm -it --restart=Never -- sh

# Read sensitive files (triggers file access detection)
kubectl run test --image=alpine --rm -it --restart=Never -- cat /etc/shadow

# Attempt privilege escalation
kubectl run test --image=alpine --rm -it --restart=Never -- sh -c "whoami && id"

📁 Project Structure
basic

k8s-threat-detection-lab/
│
├── 📂 ansible/
│   ├── deploy-falco.yml          # Full deployment automation
│   ├── requirements.yml          # Ansible dependencies
│   └── README.md
│
├── 📂 kubernetes/
│   ├── 📂 falco/
│   │   └── falco-values.yaml     # Helm configuration
│   └── 📂 webapp/
│       ├── frontend.yaml
│       ├── backend.yaml
│       ├── database.yaml
│       └── network-policies.yaml
│
└── README.md

🛠️ Tech Stack
Component	Purpose
AKS	Managed Kubernetes cluster
Falco	Runtime threat detection via eBPF
Azure Log Analytics	SIEM / centralized logging
Container Insights	Log collection agent
Calico	Network policy enforcement
Helm	Kubernetes package management
Ansible	Infrastructure as Code
💡 Lessons Learned

    Event Hub Integration is Tricky - Falcosidekick's Azure Event Hub output requires Workload Identity, not connection strings. Pivoted to Log Analytics via Container Insights instead.

    eBPF > Kernel Module - The eBPF driver is the way to go for modern clusters. No kernel headers needed, lower overhead.

    JSON Output is Essential - Enabling jsonOutput: true in Falco makes parsing in Log Analytics much easier.

    Container Insights Just Works - For Azure-native SIEM integration, Container Insights is the path of least resistance.

🚀 Quick Deploy
bash

# 1. Create AKS cluster with Calico
az aks create -g k8_project -n aks1 --node-count 2 --network-plugin azure --network-policy calico

# 2. Deploy Falco
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco -n falco --create-namespace -f kubernetes/falco/falco-values.yaml

# 3. Enable monitoring
az monitor log-analytics workspace create -g k8_project -n falco-logs --location eastus
az aks enable-addons -g k8_project -n aks1 --addons monitoring --workspace-resource-id <id>

📬 Contact

Austin - LinkedIn | Blog
📄 License

MIT
"@ | Out-File -FilePath README.md -Encoding UTF8
