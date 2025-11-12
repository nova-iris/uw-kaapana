# Kaapana POC Setup - Container Access Options

**Date:** November 12, 2025  
**Issue:** Cannot access Slack to get pre-built container registry credentials

---

## Problem Summary

You need pre-built Kaapana containers or registry credentials to deploy the POC, but cannot access the Slack channel to request them from DKFZ.

---

## Solution: 3 Options Available

### Option 1: Contact DKFZ Team Directly ⭐ **RECOMMENDED FIRST STEP**

**Direct contact (Email - Recommended):**
```
To: kaapana@dkfz-heidelberg.de
Subject: Kaapana POC - Request Container Registry Access

Body:
Hello,

I am setting up a POC environment for Kaapana for [your use case - research/evaluation/testing].

I cannot access the Slack channel but need container registry credentials or a pre-built tarball 
to complete the deployment on AWS.

Could you please provide one of the following:
1. Container registry credentials (URL, username, password/token)
2. Pre-built installation tarball
3. Alternative access method to Slack

Thank you,
[Your Name]
```

**Expected Response Time:** 1-3 business days

**What to expect:**
- Registry URL and credentials (most common)
- Or pre-built tarball (~80GB for transfer)
- Or Slack invite link if Slack issue is resolvable

---

### Option 2: Build Kaapana from Source ✅ **FULLY SUPPORTED ALTERNATIVE**

This is the official alternative if you cannot get pre-built containers.

**Requirements:**
- Separate build machine (or use existing server as build machine first)
- Ubuntu 22.04 or 24.04 LTS (x64 ONLY)
- 200GB+ disk space
- 16GB+ RAM
- ~1 hour for build process

**Process Overview:**
1. **Clone repository** on build machine
2. **Install dependencies** (Docker, Helm, Python)
3. **Configure build** settings
4. **Run build** (~1 hour)
5. **Transfer artifacts** to AWS deployment server
6. **Deploy** to AWS (same as regular deployment)

**Detailed Instructions:** See `kaapana-build-from-source.md`

**Time Estimate:**
- Setup build environment: 30 minutes
- Build process: 45-90 minutes
- Transfer to AWS: 10-30 minutes (depending on network)
- Total: ~1.5-2 hours

**Advantages:**
- No external dependency
- Full control over build
- Can customize if needed
- Fully supported by Kaapana team

**Disadvantages:**
- Takes additional time
- Requires extra machine or build first then deploy
- Uses disk space during build

---

### Option 3: Use Public/Community Registries (Advanced)

Some community members maintain public Kaapana builds:

**Check:**
- Docker Hub: Search for `kaapana-*`
- GitHub Container Registry: `ghcr.io/kaapana/*`
- Community forums: https://join.slack.com/t/kaapana/shared_invite/zt-hilvek0w-ucabihas~jn9PDAM0O3gVQ/

**Risks:**
- May not be latest version
- No official support guarantee
- May have licensing issues

---

## Recommended Action Plan

### Immediate (Today):

1. **Send email to DKFZ** requesting registry access:
   ```
   kaapana@dkfz-heidelberg.de
   ```
   - Mention Slack unavailable
   - Request registry credentials or tarball

2. **While waiting for response**, prepare your AWS environment:
   - Launch EC2 instance (r5.2xlarge or r5.4xlarge)
   - Install server dependencies
   - Prepare storage directories

### If No Response (3+ days):

3. **Build from source** using your prepared AWS instance or separate build machine:
   - Follow: `kaapana-build-from-source.md`
   - ~1.5-2 hours total
   - Generate all containers and deployment scripts locally

### Deploy:

4. **Deploy to AWS** using either:
   - Registry credentials (if received from DKFZ)
   - Built containers (if built locally)
   - Pre-built tarball (if received from DKFZ)

---

## Updated Setup Plan

The main setup document (`kaapana-poc-demo-setup-plan.md`) has been updated with:
- ⚠️ Warning about Slack access requirement
- Contact information for DKFZ team
- Reference to build-from-source guide
- Options for all three scenarios

---

## Timeline Comparison

### Scenario A: Registry Credentials Obtained
- Email send: Day 0
- Receive credentials: Day 1-3
- Deploy: Day 3-4
- Total to POC: **3-5 days**

### Scenario B: Build from Source (If Registry Unavailable)
- Email send: Day 0
- Build start: Day 1 (don't wait for response)
- Build complete: Day 1 (after ~1.5-2 hours)
- Deploy: Day 1-2
- Total to POC: **1-2 days** (can start immediately while waiting for email response)

### Scenario C: Wait for Pre-built Tarball
- Email send: Day 0
- Receive tarball: Day 1-3
- Download/transfer: Day 2-4 (large file ~80GB)
- Deploy: Day 4-5
- Total to POC: **4-6 days**

---

## Files Created/Updated

1. **`kaapana-poc-demo-setup-plan.md`** - UPDATED
   - Added warning about Slack/registry access
   - Added contact information
   - Added references to build-from-source guide

2. **`kaapana-build-from-source.md`** - NEW
   - Complete guide to building from source
   - Step-by-step instructions
   - Troubleshooting section
   - Transfer procedures

---

## Quick Reference

### Build from Source (Quick Start)

```bash
# 1. On Ubuntu 22.04/24.04 build machine
sudo apt install -y git python3-venv docker.io docker-compose

# 2. Clone and prepare
git clone -b master https://github.com/kaapana/kaapana.git
python3 -m venv kaapana/.venv
source kaapana/.venv/bin/activate

# 3. Install build tools
python3 -m pip install -r kaapana/build-scripts/requirements.txt

# 4. Configure and build
./kaapana/build-scripts/start_build.py
# Edit build-config.yaml
./kaapana/build-scripts/start_build.py

# 5. Transfer results to AWS deployment server
scp -r kaapana/build/kaapana-admin-chart ubuntu@<AWS_IP>:~/
scp kaapana/build/deploy_platform.sh ubuntu@<AWS_IP>:~/
```

---

## Support Contacts

**Kaapana Team:**
- Email: kaapana@dkfz-heidelberg.de
- Slack: https://join.slack.com/t/kaapana/shared_invite/zt-hilvek0w-ucabihas~jn9PDAM0O3gVQ/

**Documentation:**
- Official: https://kaapana.readthedocs.io/en/latest/
- Build Guide: https://kaapana.readthedocs.io/en/latest/installation_guide/build.html

---

## Next Steps

1. ✅ Read this document (you are here)
2. 📧 Send email to DKFZ requesting registry credentials
3. 🏗️ While waiting, either:
   - Prepare AWS environment
   - Start building from source (doesn't require waiting for response)
4. 🚀 Deploy using whichever method gets you credentials/artifacts first

---

**Recommendation:** Send the email immediately AND start building from source in parallel. Whichever completes first (registry credentials or local build) can be used for deployment.

**This ensures minimal delay for your POC setup!**
