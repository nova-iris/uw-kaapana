
### Milestone 1 – Environment Preparation & Familiarization ($75)
Objective: Prepare infrastructure and get comfortable with Kaapana architecture.
Tasks
* Review Kaapana documentation and module structure
* Join Kaapana Slack community
* Prepare single VM (e.g., 16 vCPU / 64GB RAM / 1TB storage, Ubuntu 22.04)
* Install Docker, Kubernetes (kubeadm/minikube/k3s), Helm, and prerequisites
Deliverable:
* Working Kubernetes environment ready for Kaapana installation
* Summary notes on Kaapana modules and dependencies

---

### Milestone 2 – Base Platform Installation ($125)
Objective: Install the Kaapana base platform and core services.
Tasks
* Configure and setup parameters for single-node deployment
* Run installation script
* Troubleshoot image pulls, network access, or Helm chart dependencies
* Verify platform pods running
Deliverable:
* Kaapana base platform successfully deployed
* Dashboard and Keycloak login accessible
---

### Milestone 3 – Core Modules Configuration ($200)
Objective: Enable and validate key Kaapana modules.

Focus modules (from docs):

* dcm4chee – DICOM storage and PACS server

* Elasticsearch / Kibana – indexing and visualization

* MinIO – object storage backend

* Airflow – workflow orchestration
Tasks

* Enable modules via configuration

* Deploy and test data upload to dcm4chee

* Validate connectivity between modules
Deliverable:

* Core modules operational and integrated

* Sample DICOM data stored and visible through Kaapana UI

---

### Milestone 4 – Verification, Documentation & Demo ($100)
Objective: Validate system functionality and hand over documentation.
Tasks

* Test login, storage, and workflow pipelines

* Verify persistence (restart and confirm data still accessible)

* Document:

* Installation steps

* Commands used

* Access URLs and credentials

* Prepare short demo or screenshots for client review
Deliverable:

* Working POC environment

* Documentation + verification checklist

* Demo-ready setup