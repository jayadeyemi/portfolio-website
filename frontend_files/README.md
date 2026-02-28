# Frontend Files

Static website assets served via S3 + CloudFront.

## Page Structure

```mermaid
graph LR
  subgraph "Landing Page (/)"
    IDX[index.html] --> CSS[styles.css]
    IDX --> JS[scripts.js]
    IDX --> IMG[profile_pic.jpg]
  end

  subgraph "Spotify Page (/myspotify/)"
    SIDX[index.html] --> SCSS[styles.css]
    SIDX --> SJS[main.js.tmpl]
    SJS -->|fetch| JSON[/data/spotify_data.json]
  end

  IDX -.->|nav link| SIDX
  SIDX -.->|back link| IDX
```

## Design System

- **Theme:** Dark slate (`#0c0f14`) + warm gold accent (`#c9a84c`)
- **Typography:** Inter (body) + JetBrains Mono (numbers/tags)
- **Layout:** CSS Grid + Flexbox, mobile-first responsive
- **Animations:** IntersectionObserver scroll reveals with staggered children

## Sections

| Section | Content |
|---------|---------|
| **Hero** | Name, title, stats, CTAs |
| **About** | Bio, profile photo, meta |
| **Expertise** | 4 capability cards with SVG icons |
| **Stack** | Categorized technology pills |
| **Certifications** | 6 cert cards with tier indicators |
| **Projects** | 3 project cards with tech tags |
| **Contact** | Email, LinkedIn, GitHub cards |

## Adding Files

1. Add file to `frontend_files/`
2. Add filename to `s3_file_list` in `infrastructure/secrets.tfvars`
3. Use `.tmpl` extension for files needing Terraform variable injection
4. `terraform plan && terraform apply`
