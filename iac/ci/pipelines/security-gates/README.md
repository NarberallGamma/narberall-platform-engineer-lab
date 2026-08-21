# Security gates consumer + scripts

**Business first:** scan jobs **create a DefectDojo engagement, import findings, and upload an SBOM to Dependency-Track**. This folder is the consumer wiring, not a second copy of Trivy or Sonar job bodies. Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

I used this repo as the security group project (`security/security-gates`). App pipelines include the templates or trigger `templates/security-pipeline.yml.example`. Scripts are cloned into the job (`CI_JOB_TOKEN`) so scanners do not vendor curl payloads.

Trivy lives in [`../werf-retail/`](../werf-retail/). Sonar and AppSec tool includes live in [`../java-gradle/`](../java-gradle/) and werf-retail. Those bodies are not copied here.

```text
security-gates/
  .gitlab-ci.yml.example                      # consumer: Gitleaks, Semgrep, CycloneDX, Dependency-Track
  templates/defectdojo.yml.example            # .pre engagement + import + DT hidden jobs
  templates/security-pipeline.yml.example     # trigger target (same jobs, thinner Semgrep flags)
  scripts/
    defectdojo_create_engagement.sh
    defectdojo_import_scan.sh
    dependency_track_upload.sh
```

LLM DEV pipeline triggers the template: [`../helmfile-dev/`](../helmfile-dev/).

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Group vs project variables | URL and tokens on the security group. Product id and `CDXGEN_LANG` per app |
| `.fetch_scripts` clone | Jobs `git clone` this repo into `/tmp/security-scripts` then run the shell next to the YAML |
| Engagement dotenv | `.pre` writes `DEFECTDOJO_ENGAGEMENTID` for later import jobs |
| Four scanners | Gitleaks secrets, Semgrep SAST, cdxgen SBOM, Dependency-Track then DefectDojo |
| `allow_failure` | Gitleaks always soft. Semgrep soft on exit 1. Gates that fail closed on noise get bypassed |

Group CI/CD variables (set once on the security group):

- `DEFECTDOJO_URL` (example `https://defectdojo.example.com/api/v2`)
- `DEFECTDOJO_TOKEN` (masked)
- `DT_API_KEY` (masked)

Project CI/CD variables (unique per product): `DEFECTDOJO_PRODUCTID`, `CDXGEN_LANG`.

## Honest gaps

- Tokens are GitLab CI variables. Files show names and placeholder URLs only.
- Scripts use `curl --insecure` / `-k`. That is the live shape (TLS verify off).
- `templates/security-pipeline.yml.example` includes `templates/defectdojo.yml.example` from project `security/security-gates`. A copy that keeps the `.example` names loads. A live private repo usually drops the suffix.
- OSV-Scanner is not in this tree. Not invented.
- Host listen address in the DT template is documentation-range `http://10.10.0.20:8081`.

**Keywords:** GitLab CI, DefectDojo, Dependency-Track, Gitleaks, Semgrep, CycloneDX, SBOM
