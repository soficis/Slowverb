#!/usr/bin/env bash
set -euo pipefail

npm run build

FLUTTER_VERSION="3.41.2"
FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_SHA256="4a04f8a6152986d14fc137ffaf98106ca743c0f9ab66f1bc2f20ee84eb573e5c"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_ARCHIVE}"
FLUTTER_CACHE_ROOT="${HOME}/.cache/slowverb-flutter"
FLUTTER_SDK_ROOT="${FLUTTER_CACHE_ROOT}/flutter-${FLUTTER_VERSION}"

install_flutter() {
  mkdir -p "${FLUTTER_CACHE_ROOT}"
  if [[ -x "${FLUTTER_SDK_ROOT}/bin/flutter" ]]; then
    return
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN

  local archive_path="${tmp_dir}/${FLUTTER_ARCHIVE}"
  echo "Installing Flutter ${FLUTTER_VERSION}..."
  curl --fail --location --silent --show-error "${FLUTTER_URL}" --output "${archive_path}"

  local actual_sha
  actual_sha="$(sha256sum "${archive_path}" | awk '{print $1}')"
  if [[ "${actual_sha}" != "${FLUTTER_SHA256}" ]]; then
    echo "Flutter archive checksum mismatch. Expected ${FLUTTER_SHA256}, got ${actual_sha}." >&2
    exit 1
  fi

  tar --no-same-owner -xf "${archive_path}" -C "${tmp_dir}"
  rm -rf "${FLUTTER_SDK_ROOT}"
  mv "${tmp_dir}/flutter" "${FLUTTER_SDK_ROOT}"
}

if ! command -v flutter >/dev/null 2>&1; then
  install_flutter
  export PATH="${FLUTTER_SDK_ROOT}/bin:${PATH}"
fi

if [[ -d "${FLUTTER_SDK_ROOT}" ]]; then
  git config --global --add safe.directory "${FLUTTER_SDK_ROOT}"
fi
flutter --version
flutter config --no-analytics
flutter pub get --enforce-lockfile
flutter build web --release --no-pub
