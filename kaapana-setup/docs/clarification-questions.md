

1. Do you have servers for build and deployment? if yes, what is the specs (CPU, RAM, storage, OS, GPU)?
can create any amount of servers, cpu etc as virtual server
2. Do you want to deploy Kaapana in single node or multi node env?
need to be able to scale with more users more data
3. will this environment have internet access or internal internet only? any firewall, DNS, proxy and SSL setup requirement?
we will be able to access using secure connection, but its mainly for internal use not for public internet access
4. How much data (image, logs, models) do you anticipate?
one module on this kappana need to be able to store hundresds milions of records (the module is dcm4chee)
5. Do you have any requirement about uptime, backup, disaster recovery,..?
its mainly for research so it can be down for 24 hours if needed some maintainance
6. What timeline or phases do you expect (POC, testing, go-live)?
I want POC first ASAP , then move to testing, go-live january

## Clarification Questions and Answers
1. Demo Purpose: What is the primary goal of this demo? Is it for:
    - Technical evaluation of Kaapana capabilities
    - Clinical workflow demonstration
  2. Target Audience: Who will be viewing/using this demo
    - Technical developers/engineers
  3. Demo Duration: Is this for:
    - Development/testing environment

  Infrastructure and Resource Questions:

  4. Deployment Environment: Where will the demo be deployed?
    - Cloud provider (AWS, Azure, GCP, DigitalOcean)
    - On-premises server once the demo is validated
    - Do you have preferred cloud provider? AWS and DigitalOcean are good
  5. Resource Constraints: What's the available budget/hardware?
    - we can meet the minimum requirements (8 cores, 64GB RAM, 200GB storage)
    - we target minimal setup first then full-featured demo
  6. Timeline: How much time do we have for setup?
    - 2 weeks for the full demo setup
    - Build from source vs use pre-built containers? Use pre-built containers for faster setup then build from source later if needed

  Content and Data Questions:

  7. Demo Data: What medical imaging data will be used?
    - Sample/public datasets
    - Do you have specific DICOM datasets to showcase? not yet, we can use public datasets for demo
  8. Workflows to Demonstrate: Which specific features should be highlighted?
    - DICOM image processing and analysis
    - AI-based segmentation (nnU-Net, TotalSegmentator)
    - Workflow orchestration with Airflow
    - Multi-center data federation
    - User management and collaboration
  9. Integration Requirements: Should the demo integrate with:
    - PACS systems (e.g., dcm4chee)? I'm not sure yet

  Configuration Questions:

  10. Authentication: How should user authentication be configured?
    - Simple demo accounts
  11. Networking: Any specific network/security requirements?
    - Internet access during demo
    - HTTPS/SSL certificates needed? No
    - Firewall/port restrictions? No
  12. Persistence: Should demo data/results be saved?
    - Persistent storage for showcase? Yes
    - Database backup requirements? No

## Additional Clarifying Questions
1. Deployment Target & Timeline
Should the demo-plan.md focus specifically on POC setup (the immediate "ASAP" phase), or should it include phases for testing and go-live (January)?
POC setup is the priority and focus.

Should I provide separate sections for each phase (POC → Testing → Production), or primarily focus on the POC? 
Primarily focus on the POC setup.

2. Infrastructure Details
Will you be providing the container registry credentials or pre-built tarball from the DKFZ Kaapana team, or should the plan assume you'll need to build from source?
Provide pre-built containers for faster setup. Also build from source in separate document later.

Should I assume a single cloud provider (AWS or DigitalOcean preferred based on clarification questions), or should the plan be provider-agnostic?
The plan should be provider-agnostic. Refer AWS.

3. Build vs Deploy Decision
The minimal setup investigation recommends skipping the build phase (~1.5-2 hours saved). Should the plan assume this approach, or include building from source as an alternative?
pre-built containers for faster setup. Also build from source in separate document later.

4. DICOM Data & Testing
Should the plan include instructions for uploading sample public DICOM datasets to demonstrate the workflow? Yes, include instructions for uploading sample public DICOM datasets.
Do you need specific instructions for testing DICOM transmission via DIMSE protocol, or is UI-based upload sufficient for the demo? UI-based upload is sufficient for the demo.
5. dcm4chee Integration
The clarification noted uncertainty about dcm4chee integration—should the plan include setting up dcm4chee as a PACS system, or focus on core Kaapana components only?
Focus on the core components first, then integration later

6. Documentation Level
Should the plan include actual command examples for each step, or more of a high-level conceptual guide?
no, just high level and successful observation/confirmation

Do you need troubleshooting scripts prepared in advance, or just documentation?
no

7. Scope - Core Workflows
Should the demo showcase all mentioned workflows (DICOM processing, nnU-Net segmentation, TotalSegmentator, Airflow workflows, multi-center federation, user management), or focus on a subset?
Focus on DICOM processing, nnU-Net segmentation, Airflow workflows, and user management.
