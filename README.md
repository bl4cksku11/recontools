## External Pentest Recon Tooling — Kali Linux Installer

A single-script installer that sets up the full offensive recon stack used for external network penetration testing engagements. Designed for Kali Linux, but compatible with any Debian-based system.

### What it installs

**System packages (apt)**
Core dependencies: `nmap`, `curl`, `wget`, `git`, `python3`, `jq`, `dnsutils`, `whois`, `libpcap-dev`, and build essentials. These are prerequisites for the tools that follow.

**ProjectDiscovery suite (Go)**
The backbone of the recon workflow — all compiled from source and copied to `/usr/local/bin`:
- `subfinder` — passive subdomain enumeration using multiple OSINT sources
- `httpx` — fast HTTP probing, tech detection, and status fingerprinting across large host lists
- `dnsx` — DNS resolution and validation at scale
- `nuclei` — template-based vulnerability scanner (restricted to `critical/high`, no DoS or fuzz templates during engagements)
- `katana` — web crawler for JS endpoint and parameter discovery
- `ffuf` — web fuzzer for hidden paths, vhosts, and parameter enumeration
- `amass` — ASN mapping, DNS enumeration, and attack surface discovery

**Secret scanning**
- `trufflehog` — scans public Git repos and filesystems for exposed credentials, API keys, and tokens using entropy and pattern detection
- `gitleaks` — SAST-style secret detection in Git history and staged code

**Cloud enumeration**
- `cloud_enum` — enumerates public resources across AWS, Azure, and GCP given a target keyword or domain (installed to `/opt/recon-tools/cloud_enum`, symlinked to `/usr/local/bin`)
- `s3scanner` — validates S3 bucket existence and tests for public read/write access

**Post-install**
After all tools are installed, the script automatically runs `nuclei -update-templates` to pull the latest CVE and misconfiguration templates before the first engagement.

### How it works

The script is idempotent — it checks whether each tool is already present before attempting installation, so re-running it after a partial failure is safe and won't duplicate work.

Go tools are compiled via `go install` and copied to `/usr/local/bin` so they are available system-wide, not just for the user who ran the install. A `PATH` entry for Go binaries is written to `/etc/profile.d/go.sh` for persistence across reboots.

All installation output is logged to `/tmp/recon_install.log`. The script ends with a verification table showing install status for every tool, so failures are immediately visible without scrolling through the full output.

### Usage

```bash
chmod +x install_recon_tools.sh
sudo bash install_recon_tools.sh
```

Requires root. Tested on Kali Linux 2024.x (amd64).

### Tool index

| Tool | Category | Source |
|------|----------|--------|
| nmap | Port scanning | apt |
| subfinder | Subdomain enum | ProjectDiscovery |
| httpx | HTTP probing | ProjectDiscovery |
| dnsx | DNS resolution | ProjectDiscovery |
| nuclei | Vuln scanning | ProjectDiscovery |
| katana | Web crawling | ProjectDiscovery |
| ffuf | Fuzzing | ffuf |
| amass | ASN / DNS mapping | OWASP |
| trufflehog | Secret scanning | Truffle Security |
| gitleaks | Secret scanning | gitleaks |
| cloud_enum | Cloud enum | initstring |
| s3scanner | S3 exposure | s3scanner |
