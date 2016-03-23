# Copyright (c) 2016, Ruslan Baratov
# All rights reserved.

include(CMakeParseArguments) # cmake_parse_arguments

include(hunter_check_download_error_message)
include(hunter_internal_error)
include(hunter_status_debug)
include(hunter_test_string_not_empty)
include(hunter_user_error)

function(hunter_download_cache_meta_file)
  hunter_test_string_not_empty("${HUNTER_CACHED_ROOT}")

  cmake_parse_arguments(x "" "LOCAL;DONE" "" ${ARGV})
  # -> x_LOCAL
  # -> x_DONE
  # -> x_UNPARSED_ARGUMENTS

  string(COMPARE NOTEQUAL "${x_UNPARSED_ARGUMENTS}" "" has_unparsed)
  if(has_unparsed)
    hunter_internal_error("Unparsed: ${x_UNPARSED_ARGUMENTS}")
  endif()

  string(COMPARE EQUAL "${x_LOCAL}" "" is_empty)
  if(is_empty)
    hunter_internal_error("LOCAL can't be empty")
  endif()

  string(COMPARE EQUAL "${x_DONE}" "" is_empty)
  if(is_empty)
    hunter_internal_error("DONE can't be empty")
  endif()

  set(cache_directory "${HUNTER_CACHED_ROOT}/_Base/Cache")
  hunter_lock_directory("${cache_directory}" "")

  string(REPLACE "${cache_directory}/meta/" "" suffix "${x_LOCAL}")

  if(EXISTS "${x_DONE}")
    return()
  endif()

  file(REMOVE "${x_LOCAL}")

  string(COMPARE EQUAL "${HUNTER_USE_CACHE_SERVERS}" "NO" disable_server)
  if(disable_server)
    hunter_status_debug("Skip servers")
    return()
  endif()

  foreach(server ${HUNTER_CACHE_SERVERS})
    string(REGEX MATCH "^https://github.com/" is_github "${server}")
    if(NOT is_github)
      hunter_user_error("Unknown cache server: ${server}")
    endif()

    string(
        REPLACE
        "https://github.com/"
        "https://raw.githubusercontent.com/"
        url
        "${server}"
    )

    set(url "${url}/master/${suffix}")

    set(total_retry 3)
    foreach(x RANGE ${total_retry})
      hunter_status_debug("Downloading file (try #${x} of ${total_retry}):")
      hunter_status_debug("  ${url}")
      hunter_status_debug("  -> ${x_LOCAL}")

      file(DOWNLOAD "${url}" "${x_LOCAL}" STATUS status)

      list(GET status 0 error_code)
      list(GET status 1 error_message)

      hunter_check_download_error_message(
          ERROR_CODE "${error_code}"
          ERROR_MESSAGE "${error_message}"
          REMOVE_ON_ERROR "${x_LOCAL}"
      )

      if(error_code EQUAL 0)
        file(WRITE "${x_DONE}" "")
        return()
      elseif(error_code EQUAL 22)
        hunter_status_debug("File not found")
        break()
      else()
        hunter_status_debug("Downloading error, retry...")
      endif()
    endforeach()
  endforeach()
endfunction()
