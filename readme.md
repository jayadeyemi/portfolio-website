# Portfolio Website — Serverless Spotify Data Visualization

A fully serverless, production-grade portfolio website featuring multi-user Spotify data visualization, infrastructure-as-code with Terraform, and OAuth 2.0 PKCE authentication on AWS.

**Repository:** [jayadeyemi/portfolio-website](https://github.com/jayadeyemi/portfolio-website)  
**Live Site:** [babasanmiadeyemi.com](https://babasanmiadeyemi.com)  

---

## ✨ Features

- **Serverless Architecture**: S3, CloudFront, Lambda, API Gateway, DynamoDB — no servers to manage
- **Multi-User Spotify Integration**: OAuth 2.0 PKCE for secure visitor authorization
- **Encrypted Token Storage**: KMS encryption for sensitive Spotify tokens
- **Automated Data Pipeline**: EventBridge-triggered Lambda processes Spotify data on a schedule
- **Infrastructure as Code**: Fully modular Terraform with reusable modules
- **CDN Delivery**: CloudFront with automatic cache invalidation
- **Professional Design**: Responsive, dark-mode portfolio with timeline components
- **Version Control**: Full Git history with releases and tagged versions

---

## 📐 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ Users Visit: babasanmiadeyemi.com                           │
└────────────────────┬────────────────────────────────────────┘
                     │
        Route 53 DNS Resolution
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ CloudFront Distribution (E2OMVBFKSAZZIT)                    │
│ - TLS Termination (ACM Certificate)                         │
│ - Global Edge Caching                                       │
└─────────────────┬───────────────────────────────────────────┘
                  │
        Origin Access Control (OAC)
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ S3 Bucket (portfolio-bucket-bja01)                          │
│ - Static HTML, CSS, JS, Images (27 files)                   │
└─────────────────────────────────────────────────────────────┘
                     │
         API Requests via JavaScript
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ API Gateway (HTTP API t2avwvlxad)                           │
│ - POST /api/auth/authorize (Spotify OAuth)                  │
│ - POST /api/auth/callback (Exchange code for token)         │
│ - GET /api/spotify/[endpoint] (Proxy to Spotify API)        │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ AWS Lambda (portfolio-lambda-function)                      │
│ - OAuth token exchange                                      │
│ - Spotify API request proxying                              │
│ - Session management                                        │
│ - KMS encryption/decryption                                 │
└─────────────────┬───────────────────────────────────────────┘
                  │
      ┌───────────┴───────────┐
      │                       │
      ▼                       ▼
┌──────────────────────┐  ┌──────────────────────┐
│ DynamoDB Tables      │  │ KMS Key              │
│ - users              │  │ - AES-256 Encryption │
│ - sessions           │  │ - Automatic Rotation │
│ - spotify_tokens     │  └──────────────────────┘
│ - insights           │
│ - access_requests    │
│ - play_history       │
└──────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ EventBridge Schedule (Every 3 days)                         │
│ - Triggers Lambda to refresh owner's Spotify data          │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- AWS Account with IAM credentials configured locally
- Terraform >= 1.0
- Git
- Spotify Developer App (register at [developer.spotify.com](https://developer.spotify.com/dashboard))

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/jayadeyemi/portfolio-website.git
   cd portfolio-website
   ```

2. **Create Spotify OAuth app:**
   - Visit [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)
   - Create a new app and note `Client ID` and `Client Secret`
   - Set redirect URI to `http://127.0.0.1:8888/callback`

3. **Create Terraform variables:**
   ```bash
   cd infrastructure
   cp terraform.tfvars.sample secrets.tfvars
   ```
   Edit `secrets.tfvars` with your:
   - AWS region, project suffix, domain name
   - Spotify credentials
   - Owner Spotify user ID and admin email

4. **Initialize and deploy:**
   ```bash
   export AWS_PAGER=""
   terraform init
   terraform plan -var-file=secrets.tfvars -out=tfplan -lock=false
   terraform apply tfplan -lock=false
   ```

5. **Authorize admin Spotify account:**
   - Visit your deployed website's `/myspotify/` page
   - Click "Connect Admin Account" button
   - Complete Spotify OAuth authorization
   - Your credentials will be permanently stored and refreshed automatically

---

## 📁 Directory Structure

```
portfolio-website/
├── frontend_files/                  # All static frontend assets
│   ├── index.html                   # Home page (About)
│   ├── experience.html              # Professional experience & skills
│   ├── projects.html                # Featured projects
│   ├── contact.html                 # Contact info
│   ├── privacy.html                 # Privacy notice
│   ├── cookies.html                 # Cookie policy
│   ├── styles.css                   # Main stylesheet
│   ├── scripts.js                   # Shared utilities
│   ├── profile_pic.jpg              # Profile picture
│   ├── myspotify/                   # Owner's Spotify data (public)
│   └── yourspotify/                 # Visitor OAuth flow + data
│
├── backend_files/
│   ├── lambda_function.py           # Lambda handler (2232 lines)
│   ├── data_extractor.py            # Extracts owner Spotify data
│   └── README.md                    # Backend documentation
│
├── infrastructure/                  # Terraform IaC
│   ├── main.tf                      # Root module
│   ├── locals.tf                    # Computed values
│   ├── variables.tf                 # Variable definitions
│   ├── outputs.tf                   # Outputs
│   ├── providers.tf                 # AWS provider config
│   ├── terraform.tfvars.sample      # ⭐ COPY & EDIT to secrets.tfvars
│   ├── README.md                    # Infrastructure docs
│   └── modules/
│       ├── frontend/                # S3, CloudFront, Route53, ACM, OAC
│       ├── backend/                 # Lambda, IAM
│       ├── dynamodb/                # 6 DynamoDB tables
│       ├── secrets/                 # Secrets Manager
│       ├── kms/                     # KMS key
│       ├── api_gateway/             # HTTP API
│       ├── triggers/                # EventBridge
│       └── uploader/                # S3 object upload
│
├── scripts/                         # (Empty — CLI scripts deprecated)
│
├── create.sh                        # Dev helper
├── destroy.sh                       # Dev helper
└── README.md                        # 👈 This file
```

---

## 🔐 Security Highlights

- **OAuth 2.0 PKCE**: Secure Spotify authorization with code exchange
- **KMS Encryption**: All Spotify tokens encrypted at rest with AES-256
- **HTTPS/TLS**: CloudFront ACM certificate for all traffic
- **Least Privilege IAM**: Lambda has minimal required permissions
- **Origin Access Control**: S3 bucket restricted to CloudFront only

---

## 💰 Cost Optimization

Estimated monthly cost: **~$4-5** (production infrastructure)

| Service | Monthly Cost |
|---------|--------------|
| Lambda | $0.20 |
| DynamoDB | $1-2 |
| API Gateway | $0.50 |
| S3 | <$0.10 |
| CloudFront | $0.50 |
| Route 53 | $0.50 |
| KMS | $1.00 |
| Secrets Manager | $0.40 |

All services are within the free tier if account is <12 months old.

---

## 🛠️ Development & Deployment

### Update Frontend

```bash
cd infrastructure
# Edit frontend_files/ as needed, then:
terraform apply -var-file=secrets.tfvars -lock=false

# Invalidate CloudFront cache manually:
aws cloudfront create-invalidation \
  --distribution-id E2OMVBFKSAZZIT \
  --paths "/*" \
  --profile jayadeyemi
```

### Update Lambda

```bash
# Edit backend_files/lambda_function.py, then:
terraform apply -var-file=secrets.tfvars -lock=false
```

### Release Process

```bash
# Commit changes
git add frontend_files/ infrastructure/ backend_files/
git commit -m "feat: description of changes"
git push origin Dynamic-Login

# On main branch, merge with release tag
git checkout main
git merge --ff-only Dynamic-Login
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin main --tags
```

---

## 📋 Terraform Modules

| Module | Resources | Purpose |
|--------|-----------|---------|
| **frontend** | CloudFront, S3, Route53, ACM, OAC | Static website delivery |
| **backend** | Lambda, IAM role, CloudWatch logs | API backend |
| **dynamodb** | 6 DynamoDB tables with TTL | Data persistence |
| **kms** | KMS key (AES-256) | Encryption at rest |
| **api_gateway** | HTTP API, routes, CORS | API endpoint |
| **uploader** | S3 objects | Frontend asset upload |
| **triggers** | EventBridge schedule rule | Periodic data refresh |
| **secrets** | Secrets Manager | Sensitive data storage |

See [infrastructure/README.md](infrastructure/README.md) for detailed module documentation.

---

## 🐛 Troubleshooting

**Frontend changes not showing?**
```bash
# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id E2OMVBFKSAZZIT \
  --paths "/*" \
  --profile jayadeyemi
```

**Spotify OAuth not working?**
- Visit `/myspotify/` page and click "Connect Admin Account" to re-authorize
- Check Lambda logs: `aws logs tail /aws/lambda/portfolio-lambda-function --follow`
- Verify Spotify app settings at [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)

**Terraform lock issues on WSL?**
```bash
# Use the -lock=false flag on all terraform commands
terraform plan -var-file=secrets.tfvars -lock=false
```

For more details, see [infrastructure/README.md](infrastructure/README.md#-troubleshooting).

---

## 📖 Additional Resources

- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Spotify Web API](https://developer.spotify.com/documentation/web-api)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [OAuth 2.0 PKCE (RFC 7636)](https://datatracker.ietf.org/doc/rfc7636/)
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)

---

## 👤 Author

**Babasanmi Adeyemi**  
Portfolio: [babasanmiadeyemi.com](https://babasanmiadeyemi.com)  
GitHub: [@jayadeyemi](https://github.com/jayadeyemi)  
LinkedIn: [linkedin.com/in/jayadeyemi](https://www.linkedin.com/in/jayadeyemi/)

---

## 🔄 Version History

| Version | Date | Changes |
|---------|------|---------|
| **1.0.0** | 2026-02-28 | Production launch — multi-user OAuth, Experience page, comprehensive docs |
| 0.8.0 | 2026-02-27 | Playlist engine, KMS encryption, project descriptions |
| 0.5.0 | 2026-02-01 | Initial Spotify integration |
| 0.1.0 | 2025-10-01 | Foundation — basic site + Terraform modules |

---

**Last Updated:** February 28, 2026  
**Repository:** [jayadeyemi/portfolio-website](https://github.com/jayadeyemi/portfolio-website)
