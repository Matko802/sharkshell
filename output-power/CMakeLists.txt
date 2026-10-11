cmake_minimum_required(VERSION 3.20)
project(quickshell-output-power LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

include(CheckIPOSupported)
check_ipo_supported(RESULT ipo_ok OUTPUT ipo_msg)
if(ipo_ok)
  set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
endif()

include(GNUInstallDirs)

find_package(Qt6 REQUIRED COMPONENTS Core Qml)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)

find_program(WAYLAND_SCANNER NAMES wayland-scanner REQUIRED)

set(PROTOCOL_FILE "${CMAKE_CURRENT_SOURCE_DIR}/protocol/wlr-output-power-management-unstable-v1.xml")
set(GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/protocol")

set(PROTOCOL_BASE "${GEN_DIR}/wlr-output-power-management-unstable-v1-client-protocol")
add_custom_command(
  OUTPUT "${PROTOCOL_BASE}.h" "${PROTOCOL_BASE}.c"
  COMMAND "${CMAKE_COMMAND}" -E make_directory "${GEN_DIR}"
  COMMAND "${WAYLAND_SCANNER}" client-header "${PROTOCOL_FILE}" "${PROTOCOL_BASE}.h"
  COMMAND "${WAYLAND_SCANNER}" private-code "${PROTOCOL_FILE}" "${PROTOCOL_BASE}.c"
  DEPENDS "${PROTOCOL_FILE}"
  VERBATIM
)
add_custom_target(output_power_protocol DEPENDS "${PROTOCOL_BASE}.h" "${PROTOCOL_BASE}.c")

add_library(quickshelloutputpower MODULE
  src/plugin.cpp
  src/output_power.cpp
  "${PROTOCOL_BASE}.c"
)
add_dependencies(quickshelloutputpower output_power_protocol)

target_include_directories(quickshelloutputpower PRIVATE "${GEN_DIR}")
target_link_libraries(quickshelloutputpower PRIVATE
  Qt6::Core
  Qt6::Qml
  PkgConfig::WAYLAND_CLIENT
)

install(TARGETS quickshelloutputpower
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt-6/qml/Quickshell/Power
)
install(FILES qmldir
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt-6/qml/Quickshell/Power
)
