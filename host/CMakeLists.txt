# Copyright (c) Open Enclave SDK contributors.
# Licensed under the MIT License.
add_custom_command(
  OUTPUT calu_u.h calu_u.c calu_args.h
  DEPENDS ${CMAKE_SOURCE_DIR}/calu.edl
  COMMAND
    openenclave::oeedger8r --untrusted ${CMAKE_SOURCE_DIR}/calu.edl
    --search-path ${OE_INCLUDEDIR} --search-path
    ${OE_INCLUDEDIR}/openenclave/edl/sgx)

add_executable(calu_host host.cpp
                               ${CMAKE_CURRENT_BINARY_DIR}/calu_u.c)

if (WIN32)
  copy_oedebugrt_target(calu_host_oedebugrt)
  add_dependencies(calu_host calu_host_oedebugrt)
endif ()

target_include_directories(
  calu_host PRIVATE # Needed for the generated file calu_u.h
                          ${CMAKE_CURRENT_BINARY_DIR})

target_link_libraries(calu_host openenclave::oehost)
