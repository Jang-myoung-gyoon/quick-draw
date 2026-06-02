#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${VERTEX_AI_PROJECT:-project-56bcbbc3-4cc7-4465-88e}"
LOCATION="${VERTEX_AI_LOCATION:-us-central1}"
CONFIG_DIR="${QUICK_DRAW_VERTEX_GCLOUD_CONFIG:-"$PWD/.vertex-ai-gcloud"}"
ADC_FILE="$CONFIG_DIR/application_default_credentials.json"

export CLOUDSDK_CONFIG="$CONFIG_DIR"
export GOOGLE_APPLICATION_CREDENTIALS="$ADC_FILE"
export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"
export GOOGLE_CLOUD_LOCATION="$LOCATION"
export GOOGLE_GENAI_USE_VERTEXAI=True

case "${1:-}" in
  -h|--help)
    exec python3 tools/generate_veo_freefall_frames.py "$@"
    ;;
esac

if [[ ! -f "$ADC_FILE" ]]; then
  echo "Vertex AI ADC credentials were not found at: $ADC_FILE" >&2
  echo "Login only for this tool with:" >&2
  echo "  tools/vertex_veo_adc_login.sh" >&2
  exit 1
fi

exec python3 tools/generate_veo_freefall_frames.py "$@"
