# oracle-vm-always-free

Get a **4 OCPU / 24 GB ARM VM that's free forever** on Oracle Cloud's Always Free tier — no monthly bill, no credit card charge, no time limit. This repo automates the whole thing with Terraform: create an Oracle Cloud account, generate credentials, and run one command to get a running VM with a public IP.

What you put on the VM afterwards is entirely up to you — a personal server, a side project, a self-hosted app like [lucid-rag](https://github.com/shivajithmutteal/lucid-rag). This repo only gets you the box.

The one real obstacle is Oracle's **"out of host capacity"** error, which is common and expected on this shape. This guide walks through it and this repo includes a script that handles it for you.

---

## What you get

| | |
|---|---|
| **VM** | Ampere A1.Flex (ARM): up to 4 OCPU / 24 GB RAM, depending on your account (see [Sizing](#sizing-your-account-may-differ)) |
| **Network** | A VCN, public subnet, and firewall rules (SSH + one app port) |
| **Cost** | **$0/month, forever** — within Always Free limits |
| **Setup time** | ~15 minutes for the account, ~2 minutes for the VM (once capacity is available) |

---

## Part 1 — Create an Oracle Cloud Free Tier account

Skip this if you already have one.

1. Go to **[oracle.com/cloud/free](https://www.oracle.com/cloud/free/)** and click **Start for free**.
2. Fill in your details (name, email, address) and verify your email — a confirmation link is sent immediately.
3. **Phone verification** — Oracle sends an SMS/call code.
4. **Payment verification** — Oracle requires a card even for the free tier, to confirm you're a real, unique account holder. **You will not be charged** unless you explicitly upgrade to Pay As You Go later. A debit card is accepted (confirmed working for India-issued debit cards); a small temporary authorization hold may appear and reverses automatically.
5. **Pick your home region carefully.** This is the one field you can't change later without opening a new account. Oracle will suggest one based on your location (e.g. India accounts often default to `ap-hyderabad-1`, India South). Your Always Free resources live in this region only — see [Home region lock-in](#home-region-lock-in) below.
6. Wait for account activation — usually a few minutes, occasionally up to a few hours.

You'll also likely get a separate email about a **30-day / $300 trial credit**. That's a *different* thing from Always Free — see [Trial credit vs. Always Free](#trial-credit-vs-always-free).

---

## Part 2 — Get your API credentials

Terraform talks to Oracle Cloud via an API key, not your console password. Generate one:

1. In the Oracle Cloud console, click your **profile icon** (top right) → **Tenancy: `<your-tenancy>`** → copy the **Tenancy OCID**.
2. Click your profile icon → **My Profile** → copy the **User OCID**.
3. Still on **My Profile**, go to the **API keys** tab → **Add API key** → **Generate API key pair**.
   - Download the **private key** (a `.pem` file) — save it somewhere like `~/.oci/oci_api_key.pem`.
   - After generating, Oracle shows a **Configuration file preview** with a `fingerprint` value — copy it.
4. Note your **Compartment OCID** — for a new account this is usually the same as your Tenancy OCID (root compartment shows as `<your-name> (root)`).

You now have everything `terraform.tfvars` needs: tenancy OCID, user OCID, fingerprint, private key path, compartment OCID.

---

## Part 3 — Set up your machine

1. **Install Terraform** (≥ 1.0): [terraform.io/downloads](https://www.terraform.io/downloads)
2. **Generate an SSH key**, if you don't already have one — this is how you'll log into the VM:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
   ```
   (No passphrase, since this key only unlocks a VM you already control via Oracle's console — an extra passphrase adds friction without much added security here.)

---

## Part 4 — Configure and deploy

```bash
git clone <this-repo-url>
cd oracle-vm-always-free
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` in an editor. Near the top you'll find five lines with placeholder text between the quotes — for each one, **replace the entire text between the quotes** with your real value (don't append to the placeholder, replace it):

```hcl
tenancy_ocid     = "ocid1.tenancy.oc1...your value"
user_ocid        = "ocid1.user.oc1...your value"
fingerprint      = "aa:bb:cc:dd:ee:ff:..."
private_key_path = "~/.oci/oci_api_key.pem"
compartment_ocid = "ocid1.compartment.oc1...your value"
region           = "ap-hyderabad-1"   # your home region
```

| Line | Where the value comes from |
|---|---|
| `tenancy_ocid` | Console → profile icon (top right) → **Tenancy: `<your name>`** → OCID shown on that page |
| `user_ocid` | Console → profile icon → **My Profile** → OCID shown at the top |
| `fingerprint` | Shown immediately after generating the API key (My Profile → **API keys** tab) — looks like `aa:bb:cc:...` |
| `private_key_path` | Leave as-is if you saved the downloaded `.pem` to `~/.oci/oci_api_key.pem`; otherwise point it at wherever you saved it |
| `compartment_ocid` | Usually identical to `tenancy_ocid` for a new account (root compartment) — paste the same value again |

Everything else in the file (`availability_domain_index`, `instance_ocpu`, `app_port`, etc.) already has a working default — no need to touch those to get a first deploy running.

Then:

```bash
terraform init
terraform plan     # review what will be created
terraform apply    # create it
```

If this succeeds first try, you're done — skip to [Part 6](#part-6--after-deployment). Most people, especially on popular shapes/regions, will hit the error in Part 5 at least once.

---

## Part 5 — "Out of capacity" (expected — here's how to get past it)

You'll likely see this:

```
Error: Out of host capacity.
Service: Compute Instance
Error Message: Out of host capacity for shape "VM.Standard.A1.Flex" in
availability domain "AD-1"... Create the instance in a different
availability domain or shape, or try again later.
```

**This is normal, not a bug.** The Ampere A1 Always Free shape is extremely popular — it's the only genuinely useful free ARM compute most clouds offer — and Oracle's free capacity per availability domain (AD) is limited and shared across every free-tier account in that region. When it's full, requests fail immediately rather than queueing.

**Important:** Terraform does **not** retry this automatically. A failed `apply` just exits — despite what you might expect from "infrastructure as code with retries," there's no built-in backoff loop for capacity errors. You have to re-run it yourself, or use the script below.

### Option A — try a different availability domain

Most regions have 3 ADs. If AD-1 is full, AD-2 or AD-3 might not be:

```hcl
# in terraform.tfvars
availability_domain_index = 1   # 0 = AD-1, 1 = AD-2, 2 = AD-3
```

```bash
terraform apply
```

### Option B — use the retry script (recommended)

This repo includes a script that does exactly what you'd do by hand — keep re-running `terraform apply` until it works — so you don't have to babysit it.

**Linux/macOS/WSL:**
```bash
chmod +x retry-apply.sh
./retry-apply.sh              # retries every 15 min, forever
./retry-apply.sh 30           # every 30 min
./retry-apply.sh 15 20        # every 15 min, give up after 20 tries
```

**Windows (PowerShell):**
```powershell
.\retry-apply.ps1                                          # every 15 min, forever
.\retry-apply.ps1 -IntervalMinutes 30
.\retry-apply.ps1 -IntervalMinutes 15 -MaxAttempts 20
```

Leave it running in a terminal (or a background job, or a cheap always-on machine) and it will create the VM as soon as capacity opens up. In practice, most people succeed within a few hours to a day — capacity turns over as other free-tier VMs get deleted.

### Why not just switch regions?

Always Free accounts are locked to their **home region** (see below) — you can't create free resources in a different region without upgrading to Pay As You Go, which defeats the point. Cycling through ADs *within* your home region and retrying over time are the only free options.

---

## Part 6 — After deployment

`terraform apply` prints:

```
public_ip     = "1.2.3.4"
ssh_command   = "ssh -i ~/.ssh/id_ed25519 ubuntu@1.2.3.4"
app_url       = "http://1.2.3.4:3000"
```

SSH in and set the VM up however you like. A typical starting point:

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@<public-ip>

# Docker is the easiest way to run most self-hosted apps
sudo apt-get update && sudo apt-get install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER && newgrp docker
```

From here, run whatever you want. For example, to deploy **lucid-rag** (a self-hosted RAG app):

```bash
git clone https://github.com/shivajithmutteal/lucid-rag
cd lucid-rag
cp .env.example .env   # add your API key, or leave blank for local Ollama
docker compose up --build -d
```

Then visit `http://<public-ip>:3000`. Full lucid-rag deployment notes: [docs/deploy-oracle-cloud.md](https://github.com/shivajithmutteal/lucid-rag/blob/main/docs/deploy-oracle-cloud.md).

This is just one example — the VM is a normal Ubuntu ARM box; anything that runs on ARM Linux works.

---

## Resize or delete

**Resize:**
```hcl
# in terraform.tfvars
instance_ocpu      = 2
instance_memory_gb = 12
```
```bash
terraform apply
```

**Delete everything this repo created:**
```bash
terraform destroy
```

---

## Sizing (your account may differ)

Oracle's Always Free Ampere allocation has historically been **4 OCPU / 24 GB total**, but this was reduced to **2 OCPU / 12 GB** for many accounts starting mid-2026, with inconsistent rollout — some newer accounts still see 4/24, others are capped at 2/12. **Trust the number the Oracle console shows you live** (look for the "Always Free eligible" indicator when configuring a shape) over any number in this doc or in `terraform.tfvars.example`. If `terraform apply` fails with a limit/quota error rather than a capacity error, lower `instance_ocpu` / `instance_memory_gb`.

## Home region lock-in

Always Free resources can only be created in your account's **home region** — the one you picked during signup. Adding or switching regions requires upgrading to Pay As You Go. This is why "just try a different region" isn't a free option; only cycling through availability domains *within* your home region is.

## Trial credit vs. Always Free

Oracle new accounts often get **both**:
- A **30-day, $300 trial credit** — temporary, expires, and can be spent on *any* resource (including ones beyond Always Free limits).
- **Always Free resources** — permanent, no expiry, but capped to specific shapes/sizes (like the A1.Flex config this repo creates).

The VM this repo creates is sized to fit **Always Free** limits, so it keeps running (at $0) after your trial credit expires or runs out. Don't accidentally size it using trial-era generosity — check the console's Always Free indicator, not the trial dashboard.

## Cost confirmation

**$0/month**, as long as you:
- ✅ Stay within your account's Always Free OCPU/memory limits
- ✅ Don't enable Pay As You Go
- ✅ Keep the instance in your home region
- ⚠️ Watch egress traffic — 10 GB/month is free, then billed; normal SSH + light app usage stays well under this

Set a **$1 budget alert** in the console (Governance → Cost Management → Budgets) as a safety net.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "Out of host capacity" | Expected — see [Part 5](#part-5--out-of-capacity-expected--heres-how-to-get-past-it) |
| "Credentials not found" / auth errors | Check `private_key_path` points to the actual `.pem` file, and the fingerprint matches |
| Limit/quota exceeded (not a capacity error) | Lower `instance_ocpu` / `instance_memory_gb` — your account's real limit may be 2/12, not 4/24 |
| Can't SSH after creation | Confirm the security list allows port 22 (it does by default in `main.tf`); also check the VM's own firewall (iptables/firewalld) isn't blocking it separately — cloud + OS firewalls are two independent layers |
| App port unreachable | Same as above, but for `var.app_port` — also confirm the app is actually listening on `0.0.0.0`, not `127.0.0.1` |
| `terraform destroy` hangs | Ctrl+C, then re-run `terraform destroy` from a fresh terminal |

---

## Files

| File | Purpose |
|---|---|
| `main.tf` | VCN, subnet, security rules, and the instance itself |
| `variables.tf` | All configurable inputs, with validation against Always Free limits |
| `outputs.tf` | Values printed after `apply` — IP, SSH command, app URL |
| `terraform.tfvars.example` | Template — copy to `terraform.tfvars` and fill in your credentials |
| `retry-apply.sh` / `retry-apply.ps1` | Loops `terraform apply` until it succeeds — the actual fix for capacity errors |
