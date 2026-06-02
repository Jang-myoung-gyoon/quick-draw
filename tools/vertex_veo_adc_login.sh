#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${VERTEX_AI_PROJECT:-project-56bcbbc3-4cc7-4465-88e}"
LOCATION="${VERTEX_AI_LOCATION:-us-central1}"
CONFIG_DIR="${QUICK_DRAW_VERTEX_GCLOUD_CONFIG:-"$PWD/.vertex-ai-gcloud"}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is not installed. Install Google Cloud CLI first." >&2
  echo "https://cloud.google.com/sdk/docs/install" >&2
  exit 127
fi

mkdir -p "$CONFIG_DIR"
export CLOUDSDK_CONFIG="$CONFIG_DIR"

gcloud config set project "$PROJECT_ID"
gcloud auth application-default login
gcloud auth application-default set-quota-project "$PROJECT_ID"

cat <<EOF

Vertex AI ADC login is ready for this project only.

Config dir: $CONFIG_DIR
Project:    $PROJECT_ID
Location:   $LOCATION

Run Veo generation with:
  tools/run_vertex_veo_with_adc.sh
EOF
