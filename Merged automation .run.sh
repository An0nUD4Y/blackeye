#!/usr/bin/env bash

#
# Codacy Analysis CLI Wrapper
#

log_error() {
  local message=$1

  cat >&2 <<-EOF
		We encountered a problem with your Docker setup:
		  > ${message}
		
		Please check https://github.com/codacy/codacy-analysis-cli for alternative instructions.
		
	EOF
  exit 3
}

test_docker_socket() {
  if [ ! -S /var/run/docker.sock ]; then
    log_error "/var/run/docker.sock must exist as a Unix domain socket"
  elif [ -n "${DOCKER_HOST}" ] && [ "${DOCKER_HOST}" != "unix:///var/run/docker.sock" ]; then
    log_error "invalid DOCKER_HOST=${DOCKER_HOST}, must be unset or unix:///var/run/docker.sock"
  fi
}

run() {
  local output_volume="";
  if [ -n "${OUTPUT_DIRECTORY}" ]; then
    output_volume="--volume ${OUTPUT_DIRECTORY}:${OUTPUT_DIRECTORY}";
  fi
  local CODACY_ANALYSIS_CLI_VERSION="${CODACY_ANALYSIS_CLI_VERSION:-stable}"
  docker run \
    --rm \
    --env CODACY_CODE="$CODACY_CODE" \
    --env CODACY_PROJECT_TOKEN="$CODACY_PROJECT_TOKEN" \
    --env CODACY_API_TOKEN="$CODACY_API_TOKEN" \
    --env CODACY_API_BASE_URL="$CODACY_API_BASE_URL" \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume "$CODACY_CODE":"$CODACY_CODE" \
    ${output_volume} \
    --volume /tmp:/tmp \
    codacy/codacy-analysis-cli:${CODACY_ANALYSIS_CLI_VERSION} -- \
    "$@"
}

analysis_file() {
  local filename="";
  local is_filename=0;
  for arg; do
    case "$arg" in
      -*)
        case ${arg} in
          -d | --directory)
            is_filename=1 # next argument will be the directory or file
            ;;
        esac
        ;;
      *)
        if [ ${is_filename} -eq 1 ]; then
          if [ -n "$filename" ]; then
            echo "Please provide only one file or directory to analyze" >&2
            exit 1
          else
            is_filename=0
            filename="$arg"
          fi
        fi
        ;;
    esac
  done

  if [ -n "$filename" ]; then
    CODACY_CODE="$filename"
  else
    CODACY_CODE="$(pwd)"
  fi
}

prep_args_with_output_absolute_path() {
  local is_filename=0;
  local new_args="";
  for arg; do
    case "$arg" in
      -*)
        case ${arg} in
          --output)
            is_filename=1 # next argument will be the file
            ;;
        esac
        new_args="${new_args} ${arg}"
        ;;
      *)
        if [ ${is_filename} -eq 1 ]; then
          if [ -n "$OUTPUT" ]; then
            echo "Please provide only one output file" >&2
            exit 1
          else
            is_filename=0
            OUTPUT_DIRECTORY="$(cd $(dirname "${arg}") && pwd -P)"
            OUTPUT_FILENAME="$(basename "${arg}")"
            OUTPUT="${OUTPUT_DIRECTORY}/${OUTPUT_FILENAME}"
            new_args="${new_args} ${OUTPUT}"
          fi
        else
          if [ ${arg} == "analyse" ]; then
            new_args="${new_args} analyze"
          else
            new_args="${new_args} ${arg}"
          fi
        fi
        ;;
    esac
  done

  ARGUMENTS_WITH_ABSOLUTE_PATH_OUTPUT="$new_args"
}

test_docker_socket

analysis_file "$@"

prep_args_with_output_absolute_path "$@"

run $ARGUMENTS_WITH_ABSOLUTE_PATH_OUTPUT
