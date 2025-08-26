#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Generate per-service CI/CD workflows from your template
# - Looks for service folders under ./services/*
# - Writes .github/workflows/<service>-ci-cd.yml
# - Replaces all 'table-parsing-service' with <service>
# - Sets env.service_name: "<service>"
#
# Usage:
#   ./generate-workflows.sh
#   OVERWRITE=1 ./generate-workflows.sh   # overwrite existing files
#   DRY_RUN=1  ./generate-workflows.sh    # print what would be written
# ------------------------------------------------------------

SERVICES_DIR="${SERVICES_DIR:-services}"
WORKFLOWS_DIR="${WORKFLOWS_DIR:-.github/workflows}"
OVERWRITE="${OVERWRITE:-0}"
DRY_RUN="${DRY_RUN:-0}"

if [[ ! -d "$SERVICES_DIR" ]]; then
  echo "❌ No '$SERVICES_DIR' directory found. Run this at the repo root."
  exit 1
fi

mkdir -p "$WORKFLOWS_DIR"

# ---- Your provided template (verbatim) ----
read -r -d '' TEMPLATE <<'YAML'
name: Service Table Parsing (Param)

env:
  service_name: "generic serice"

on:
  push:
    branches: [ ci_test ]
    paths:
      - 'services/table-parsing-service/**'
      - '.github/workflows/table-parsing-service-ci-cd.yml'

  release:
    types: [published]

  workflow_dispatch:
    inputs:
      aws_account:
        description: "Which AWS account?"
        required: true
        type: choice
        default: "ai-dev"
        options: [ "ai-dev", "ai-inference" ]
      environment:
        description: "Environment to target"
        required: true
        type: choice
        default: "dev"
        options: [ "dev", "prod" ]
      deploy:
        description: "Deploy after build?"
        required: true
        default: "false"
        type: choice
        options: [ "true", "false" ]

permissions:
  id-token: write
  contents: read
  
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  validate-inputs:
    name: Validate account/env combo
    runs-on: ubuntu-latest
    outputs:
      aws_account: ${{ steps.out.outputs.aws_account }}
      environment: ${{ steps.out.outputs.environment }}
    steps:
      - name: Validate
        id: out
        run: |
          set -euo pipefail
          ACC="${{ github.event_name == 'workflow_dispatch' && github.event.inputs.aws_account || 'ai-dev' }}"
          ENV="${{ github.event_name == 'workflow_dispatch' && github.event.inputs.environment || 'dev' }}"

          # Rules:
          # - ai-dev supports: dev
          # - ai-inference supports: dev, prod
          case "$ACC" in
            ai-dev)
              if [ "$ENV" != "dev" ]; then
                echo "❌ ai-dev only supports ENV=dev, got '$ENV'"; exit 1
              fi
              ;;
            ai-inference)
              case "$ENV" in dev|prod) ;; * ) echo "❌ ai-inference supports ENV=dev|prod, got '$ENV'"; exit 1 ;; esac
              ;;
            *)
              echo "❌ Unknown aws_account: $ACC"; exit 1
              ;;
          esac

          echo "aws_account=$ACC" >> "$GITHUB_OUTPUT"
          echo "environment=$ENV" >> "$GITHUB_OUTPUT"
          echo "✅ Inputs OK: account=$ACC env=$ENV"

  call-centralized-build:
    name: Build & Push Table Parsing Service
    needs: validate-inputs
    uses: Parspec/parspec-ai-ci-common/.github/workflows/build-and-push.yml@main
    with:
      service-name: "table-parsing-service"
      build-context: "services/table-parsing-service"
      # pass environment through (used for secret name suffix etc.)
      env: ${{ needs.validate-inputs.outputs.environment }}
      # ALSO pass the AWS account target for OIDC role/registry mapping in the central workflow
      target: ${{ needs.validate-inputs.outputs.aws_account }}
      # Prefer release tag; else commit SHA; else 'latest'
      image-tag: >-
        ${{ github.event_name == 'release' && github.event.release.tag_name
            || github.sha
            || 'latest' }}
    # 👇 No secrets needed when using OIDC in the central workflow
    # (Ensure the central build-and-push.yml sets permissions.id-token: write and assumes the right role)

  trigger-centralized-deploy:
    name: Trigger Deploy in ci-common repo
    needs: [validate-inputs, call-centralized-build]
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.deploy == 'true' }}
    steps:
      - name: Compute image tag (match build)
        id: compute
        run: |
          set -euo pipefail
          TAG="${{ needs.call-centralized-build.outputs.image-tag }}"
          if [ -z "$TAG" ]; then
            if [ "${{ github.event_name }}" = "release" ] && [ -n "${{ github.event.release.tag_name }}" ]; then
              TAG="${{ github.event.release.tag_name }}"
            elif [ -n "${{ github.sha }}" ]; then
              TAG="${{ github.sha }}"
            else
              TAG="latest"
            fi
          fi
          echo "image_tag=$TAG" >> "$GITHUB_OUTPUT"
          echo "Env: ${{ needs.validate-inputs.outputs.environment }} | Account: ${{ needs.validate-inputs.outputs.aws_account }} | Tag: $TAG"

      - name: Send repository_dispatch to ci-common
        uses: peter-evans/repository-dispatch@v3
        with:
          token: ${{ secrets.GH_PAT_REPO }}  # PAT with access to Parspec/parspec-ai-ci-common
          repository: Parspec/parspec-ai-ci-common
          event-type: deploy-service
          client-payload: |
            {
              "service":   "${{ env.service_name }}",
              "env":       "${{ needs.validate-inputs.outputs.environment }}",
              "account":   "${{ needs.validate-inputs.outputs.aws_account }}",
              "image_tag": "${{ steps.compute.outputs.image_tag }}"
            }

      - name: Show links
        run: |
          echo "🚀 Deployment triggered!"
          echo "Centralized Deploy Workflow:"
          echo "https://github.com/Parspec/parspec-ai-ci-common/actions/workflows/deploy-dispatch.yml"
          echo ""
          echo "Build & Push (reusable):"
          echo "https://github.com/Parspec/parspec-ai-ci-common/actions/workflows/build-and-push.yml"
          echo ""
          echo "Service: ${{ env.service_name }}"
          echo "Account: ${{ needs.validate-inputs.outputs.aws_account }}"
          echo "Env:     ${{ needs.validate-inputs.outputs.environment }}"
          echo "Tag:     ${{ steps.compute.outputs.image_tag }}"
YAML

# ---- Iterate over service directories ----
shopt -s nullglob
generated=0
for dir in "$SERVICES_DIR"/*/; do
  svc="$(basename "$dir")"         # e.g., table-parsing-service
  out="${WORKFLOWS_DIR}/${svc}-ci-cd.yml"

  # Prepare file content:
  # - replace service name everywhere it appears literally in template paths/with/env
  content="$TEMPLATE"
  content="${content//Service Table Parsing (Param)/Service ${svc} (Param)}"
  content="${content//generic serice/$svc}"
  content="${content//table-parsing-service/$svc}"

  if [[ -f "$out" && "$OVERWRITE" != "1" ]]; then
    echo "↩️  Skipping existing: $out (set OVERWRITE=1 to overwrite)"
    continue
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "---- would write: $out ----"
    echo "$content"
    echo "---------------------------"
  else
    printf "%s\n" "$content" > "$out"
    echo "✅ Wrote $out"
  fi
  generated=$((generated+1))
done

if [[ $generated -eq 0 ]]; then
  echo "ℹ️ No services found under '$SERVICES_DIR/*/'. Nothing generated."
fi
