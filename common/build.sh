#!/bin/bash

# This script is used to build the OpenShift Docker images.
#
# OS - Specifies distribution - "rhel7", "centos7" or "fedora"
# VERSION - Specifies the image version - (must match with subdirectory in repo)
# VERSIONS - Must be set to a list with possible versions (subdirectories)

set -e

if [[ "$OSTYPE" == "darwin"* ]]; then
  script_name=$(greadlink -f "$0")
  script_dir=$(dirname "$script_name")
else
  script_name=$(readlink -f "$0")
  script_dir=$(dirname "$script_name")
fi

OS=${1-$OS}
VERSION=${2-$VERSION}

DOCKERFILE_PATH=""

error() { echo "ERROR: $*" ; false ; }


# _parse_output_inner
# -------------------
# Helper function for 'parse_output'.
# We need to avoid case statements in $() for older Bash versions (per issue
# postgresql-container#35, mac ships with 3.2).
# Example of problematic statement: echo $(case i in i) echo i;; esac)
_parse_output_inner ()
{
    set -o pipefail
    {
        case $stream in
        stdout|1|"")
            eval "$command" | tee >(cat - >&$stdout_fd)
            ;;
        stderr|2)
            set +x # avoid stderr pollution
            eval "$command" {free_fd}>&1 1>&$stdout_fd 2>&$free_fd | tee >(cat - >&$stderr_fd)
            ;;
        esac
        # Inherit correct exit status.
        (exit ${PIPESTATUS[0]})
    } | eval "$filter"
}


# parse_output COMMAND FILTER_COMMAND OUTVAR [STREAM={stderr|stdout}]
# -------------------------------------------------------------------
# Parse standard (error) output of COMMAND with FILTER_COMMAND and store the
# output into variable named OUTVAR.  STREAM might be 'stdout' or 'stderr',
# defaults to 'stdout'.  The filtered output stays (live) printed to terminal.
# This method doesn't create any explicit temporary files.
# Defines:
#   ${$OUTVAR}: Set to FILTER_COMMAND output.
parse_output ()
{
  local command=$1 filter=$2 var=$3 stream=$4
  local raw_output= rc=0
  {
      raw_output=$(_parse_output_inner)
  } {stdout_fd}>&1 {stderr_fd}>&2
  rc=$?
  eval "$var=\$raw_output"
  (exit $rc)
}

# "best-effort" cleanup of previous image
function clean_image {
  if test -f .image-id.raw; then
      local previous_id
      previous_id=$(cat .image-id.raw)
      if test "$IMAGE_ID" != "$previous_id"; then
          # Also remove squashed image since it will change anyway
          docker rmi "$previous_id" "$(cat .image-id)" || :
          rm -f ".image-id.raw" ".image-id" || :
      fi
  fi
}

# Perform docker build but append the LABEL with GIT commit id at the end
function docker_build_with_version {
  local dockerfile="$1"
  local exclude=.exclude-${OS}
  if [ -e "$exclude" ]; then
    echo "-> $exclude file exists for version $dir, skipping build."
    clean_image
    return
  fi
  if [ ! -e "$dockerfile" ]; then
    echo "-> $dockerfile for version $dir does not exist, skipping build."
    clean_image
    return
  fi
  echo "-> Version ${dir}: building image from '${dockerfile}' ..."

  git_version=$(git rev-parse --short HEAD)
  BUILD_OPTIONS+=" --label io.openshift.builder-version=\"${git_version}\""
  if [[ "${UPDATE_BASE}" == "1" ]]; then
    BUILD_OPTIONS+=" --pull=true"
  fi
  if [ ! -z "$CUSTOM_REPO" ]; then
    if [ -f "$CUSTOM_REPO" ]; then
      BUILD_OPTIONS+=" -v $CUSTOM_REPO:/etc/yum.repos.d/sclorg_custom.repo:Z"
    elif [ -d "$CUSTOM_REPO" ]; then
      BUILD_OPTIONS+=" -v $CUSTOM_REPO:/etc/yum.repos.d/:Z"
    else
      echo "ERROR: file type not known: $CUSTOM_REPO" >&2
    fi
  fi

  parse_output 'docker build '"$BUILD_OPTIONS"' -f "$dockerfile" "${DOCKER_BUILD_CONTEXT}"' \
               "tail -n 1 | awk '/Successfully built|^--> (Using cache )?[a-fA-F0-9]+$/{print \$NF}'" \
               IMAGE_ID
  clean_image
  echo "$IMAGE_ID" > .image-id.raw

  squash "${dockerfile}"
  echo "$IMAGE_ID" > .image-id
}

# squash DOCKERFILE
# -----------------
# Use python library docker_squash[1] and squash the result image
# when necessary.
# [1] https://github.com/goldmann/docker-squash
# Reads:
#   $IMAGE_ID
# Sets:
#   $IMAGE_ID
squash ()
{
  local base squashed_from squashed= unsquashed=$IMAGE_ID
  test "$SKIP_SQUASH" = 1 && return 0

  if test -f .image-id.squashed; then
      squashed=$(cat .image-id.squashed)
      # We (maybe) already have squashed file.
      if test -f .image-id.squashed_from; then
          squashed_from=$(cat .image-id.squashed_from)
          if test "$squashed_from" = "$IMAGE_ID"; then
              # $squashed is up2date
              IMAGE_ID=$squashed
              echo "Image '$unsquashed' already squashed as '$squashed'"
              return 0
          fi
      fi

      # We are going to squash now, so if there's existing squashed image, try
      # to do the best-effort 'rmi' to not waste memory unnecessarily.
      docker rmi "$squashed" || :
  fi

  base=$(awk '/^FROM/{print $2}' "$1")

  echo "Squashing the image '$unsquashed' from '$base' layer."
  IMAGE_ID=$("${PYTHON-python3}" "$script_dir"/squash.py "$unsquashed" "$base")

  echo "Squashed as '$IMAGE_ID'."

  echo "$unsquashed" > .image-id.squashed_from
  echo "$IMAGE_ID" > .image-id.squashed
}

# Versions are stored in subdirectories. You can specify VERSION variable
# to build just one single version. By default we build all versions
dirs=${VERSION:-$VERSIONS}

for dir in ${dirs}; do
  pushd ${dir} > /dev/null
  if [ "$OS" == "rhel8" -o "$OS" == "rhel8-candidate" ]; then
    docker_build_with_version Dockerfile.rhel8
  elif [ "$OS" == "rhel7" -o "$OS" == "rhel7-candidate" ]; then
    docker_build_with_version Dockerfile.rhel7
  elif [ "$OS" == "fedora" -o "$OS" == "fedora-candidate" ]; then
    docker_build_with_version Dockerfile.fedora
  elif [ "$OS" == "centos6" -o "$OS" == "centos6-candidate" ]; then
    docker_build_with_version Dockerfile.centos6
  else
    docker_build_with_version Dockerfile
  fi

  popd > /dev/null
done
