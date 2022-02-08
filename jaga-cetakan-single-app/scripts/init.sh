#!/bin/bash -e

# Based on https://github.com/rantav/go-template/blob/master/scripts/init.sh

TEMPLATE_ADDRESS="https://github.com/kitabisa/jaga-cetakan.git"
PROJECT_REPO_PATH="github.com/kitabisa"
CODEOWNERS="@kitabisa/kitajaga-backend"
TIMEZONE="Asia/Jakarta"
BUSINESS_UNIT="insurance"
GO_ARCHETYPE_VERSION="0.1.11"

die () {
    echo >&2 "$@"
    echo >&2 "Usage: $0 project-name"
    exit 1
}

cleanup() {
  sleep 10 ## wait for 10 seconds
  echo "Removing ${TMP_DIR:?}"
  rm -rf "${TMP_DIR:?}"
}

die_check() {
  echo "$*" 1>&2
  exit 1
}

check_preflight() {
  local GO_MAJOR_VERSION="go1"
  local GO_MINOR_VERSION="12"
  local GO_VERSION="$GO_MAJOR_VERSION.$GO_MINOR_VERSION" # Minimal required go version

  echo
  echo "Running preflight checks..."
  echo
  echo "Checking git binary..."
  which git || die_check "git is not installed or not found in \$PATH"
  echo "git binary ok"
  echo
  # Validate go exists and version >= 1.12
  echo
  echo "Checking go binary..."
  which go || die_check "go is not installed or not found in \$PATH. Please install from here with minimal version of $GO_VERSION https://golang.org/doc/install"
  echo "go binary ok"
  echo

  echo "Checking go version is at least >= $GO_VERSION"
  CURRENT_GO_VERSION_MAJOR=$(go version | grep "version go" | cut -d' ' -f3 | cut -d. -f1)
  CURRENT_GO_VERSION_MINOR=$(go version | grep "version go" | cut -d' ' -f3 | cut -d. -f2)
  echo "major: ${CURRENT_GO_VERSION_MAJOR}"
  echo "minor: ${CURRENT_GO_VERSION_MINOR}"
  [ "${CURRENT_GO_VERSION_MAJOR}" == "$GO_MAJOR_VERSION" ] || die_check "Go major version should be $GO_MAJOR_VERSION"
  [ "$CURRENT_GO_VERSION_MINOR" -ge "$GO_MINOR_VERSION" ] || die_check "Go minor version should be at least $GO_MINOR_VERSION"
  echo "OK, version check passed, found ${CURRENT_GO_VERSION_MAJOR}.${CURRENT_GO_VERSION_MINOR}"
  echo

  echo "Making sure gofmt is installed"
  which gofmt || die_check "gofmt is not installed or not found in the \$PATH. Please install from here with minimal version of $GO_VERSION https://golang.org/doc/install"
  echo "OK, gofmt validated"
  echo
  echo "Making sure helm (package manager for Kubernetes) is installed"
  which helm || die_check "helm is not installed or not found in the \$PATH. Please install: https://helm.sh/docs/intro/install/"
  echo "OK, helm validated"
  echo
  echo "Making sure helm secrets (helm plugin) is installed"
  helm secrets version || die_check "helm secrets plugin is not installed. Please install: https://github.com/jkroepke/helm-secrets"
  echo "OK, helm secrets plugin validated"
  echo

  echo "Done all preflight checks - PASSED"
  echo
}

check_go_archetype() {
  case $(uname -s | tr '[:upper:]' '[:lower:]') in
    linux*)
      RELEASE_OS=linux
      ;;
    darwin*)
      RELEASE_OS=osx
      ;;
    msys*)
      die_check "Windows not supported yet, sorry...."
      ;;
    *)
      die_check "OS not supported yet, sorry...."
      ;;
  esac

  if which go-archetype >/dev/null; then
    GO_ARCHETYPE=$(which go-archetype)
  else
    GO_ARCHETYPE_DIR="${TMP_DIR:?}/go-archetype-${GO_ARCHETYPE_VERSION}"
    rm -rf "${GO_ARCHETYPE_DIR:?}"
    mkdir -p "${GO_ARCHETYPE_DIR:?}"
    pushd "${GO_ARCHETYPE_DIR:?}"
    curl -sL https://github.com/rantav/go-archetype/releases/download/v${GO_ARCHETYPE_VERSION}/go-archetype_${GO_ARCHETYPE_VERSION}_${RELEASE_OS}_x86_64.tar.gz | tar xz
    GO_ARCHETYPE="${GO_ARCHETYPE_DIR:?}/go-archetype"
    popd
  fi

  export GO_ARCHETYPE
 "${GO_ARCHETYPE}" --help
}

clone_template() {
  rm -rf "${TMP_DIR:?}/${GIT_REPO_NAME:?}"
  git clone --depth 1 --branch "single-app" --single-branch "${TEMPLATE_ADDRESS:?}" "${TMP_DIR:?}/${GIT_REPO_NAME:?}"
}

exec_go_archetype() {
  pushd "${TEMPLATE_PATH:?}"

  local PROJECT_YEAR
  PROJECT_YEAR=$(date +%Y)

  LOG_LEVEL=info ${GO_ARCHETYPE} \
  		transform \
  		--transformations=transformations.yml \
  		--source=. \
  		--destination="${DESTINATION}" \
  		-- \
  		--project_year="${PROJECT_YEAR}" \
  		--project_repo_path="${PROJECT_REPO_PATH}" \
  		--codeowners="${CODEOWNERS}" \
  		--project_timezone="${TIMEZONE}"\
  		--business_unit="${BUSINESS_UNIT}"
  popd
}

exec_git() {
  pushd "${DESTINATION:?}"
  git init
  git config init.defaultBranch main
  git config core.hooksPath .githooks
  git add .
  git commit -m "first commit"
  git branch -M main
  { echo "git remote add origin"; cat GIT.md; } | tr "\n" " " | sh
}

[ "$#" -eq 1 ] || die "1 arguments required, only $# provided"

TMP_DIR="$(mktemp -d)"
PROJECT_NAME=$1
DESTINATION=`pwd`/${PROJECT_NAME:?}
GIT_REPO_NAME=$(echo "${TEMPLATE_ADDRESS:?}" | awk -F'\/' '{print $NF}' | awk -F"\."  '{$NF=""; print $0}')
TEMPLATE_PATH="${TMP_DIR:?}/${GIT_REPO_NAME:?}/template"

check_preflight
clone_template
check_go_archetype
exec_go_archetype
exec_git

trap cleanup EXIT
