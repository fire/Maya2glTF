# TODO: Cleanup this mess, learn CMake first Peter, even though you hate it.
# Read https://pabloariasal.github.io/2018/02/19/its-time-to-do-cmake-right/

# https://github.com/pmoulon/DO-CV/blob/master/cmake/PCH.cmake
macro( add_clang_pch _pchTarget _inputHeader _inputModule _extraDefines)
  # Extract CMAKE_CXX_FLAGS and CMAKE_CXX_FLAGS_XXX for the current configuration XXX.
  string( TOUPPER "CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}" _build_type_flags_var )
  set( _flags "${CMAKE_CXX_FLAGS} ${${_build_type_flags_var}}")

  # Convert string of space separated flags into a list.
  separate_arguments( _flags )

   # Extract definitions set by add_definitions command.
  get_directory_property( _defines COMPILE_DEFINITIONS )
  foreach( _define ${_defines} )
    list( APPEND _flags "-D${_define}" )
  endforeach()

  message("_extraDefines = ${_extraDefines}")
 
  foreach( _define ${_extraDefines} )
    list( APPEND _flags "-D${_define}" )
  endforeach()

  # Extract include directories set by include_directories command.
  get_directory_property( _includes INCLUDE_DIRECTORIES )
  foreach( _include ${_includes} )
    list( APPEND _flags "-I${_include}" )
  endforeach()
 
  # Helper target that properly triggers recompilation of precompiled header.
  add_library( ${_pchTarget}_trigger INTERFACE )
  target_sources(${_pchTarget}_trigger INTERFACE "${_inputHeader}" "${_inputModule}" )
  
  # Build precompiled header and copy original header to the build folder - GCC wants it there.
  add_custom_command( OUTPUT "${_inputHeader}.gch"
    DEPENDS ${_pchTarget}_trigger
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/${_inputHeader}" "${_inputHeader}"
    COMMAND "${CMAKE_COMMAND}" -E remove -f "${_inputHeader}.gch"
    COMMAND "${CMAKE_CXX_COMPILER}" -std=gnu++1z -o "${_inputHeader}.gch" -x c++-header "${CMAKE_CURRENT_SOURCE_DIR}/${_inputHeader}" ${_flags}
  )
  
  add_custom_target( ${_pchTarget} DEPENDS "${_inputHeader}.gch" )

  set( ${_pchTarget}_outputPCH "${CMAKE_CURRENT_BINARY_DIR}/${_inputHeader}.gch" )
endmacro()

macro( use_clang_pch _target _pchTarget )
  add_dependencies( ${_target} ${_pchTarget})
  set_target_properties( ${_target} PROPERTIES COMPILE_FLAGS "-include-pch ${${_pchTarget}_outputPCH}" )
endmacro()

cmake_minimum_required(VERSION 3.8)

project(maya2glTF)

if(NOT WIN32)
  string(ASCII 27 Esc)
  set(ColourReset "${Esc}[m")
  set(ColourBold  "${Esc}[1m")
  set(Red         "${Esc}[31m")
  set(Green       "${Esc}[32m")
  set(Yellow      "${Esc}[33m")
  set(Blue        "${Esc}[34m")
  set(Magenta     "${Esc}[35m")
  set(Cyan        "${Esc}[36m")
  set(White       "${Esc}[37m")
  set(BoldRed     "${Esc}[1;31m")
  set(BoldGreen   "${Esc}[1;32m")
  set(BoldYellow  "${Esc}[1;33m")
  set(BoldBlue    "${Esc}[1;34m")
  set(BoldMagenta "${Esc}[1;35m")
  set(BoldCyan    "${Esc}[1;36m")
  set(BoldWhite   "${Esc}[1;37m")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/modules")

if (NOT DEFINED MAYA_VERSION)
  set(MAYA_VERSION $ENV{MAYA_VERSION})
  if (NOT MAYA_VERSION)
    set(MAYA_VERSION 2018 CACHE STRING "Maya version")
  endif()
endif()

message (STATUS "${BoldMagenta}Using Maya version " ${MAYA_VERSION} "${ColourReset}")

find_package(Maya REQUIRED)

message("MAYA_COMPILE_DEFINITIONS = ${MAYA_COMPILE_DEFINITIONS}")

include(ExternalProject)

# GLTF
ExternalProject_Add(GLTF
  GIT_REPOSITORY https://github.com/WonderMediaProductions/GLTF
  GIT_TAG master
  PREFIX GLTF
  INSTALL_DIR
  CMAKE_ARGS
  -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
)

ExternalProject_Get_Property(GLTF binary_dir)
message("Using ${binary_dir} as GLTF library folder")
set(GLTF_LIBRARY_DIR "${binary_dir}") 
set(GLTF_LIBRARY_PATH "${GLTF_LIBRARY_DIR}/libGLTF.a")

# TODO: Use ExternalProject_Get_Property for include files, and fix GLTF
set(GLTF_INCLUDE_DIR          "${CMAKE_BINARY_DIR}/GLTF/include")
set(RAPIDJSON_INCLUDE_DIR     "${CMAKE_BINARY_DIR}/GLTF/dependencies/rapidjson/include")

add_library(LIB_GLTF STATIC IMPORTED)
add_dependencies(LIB_GLTF GLTF)
set_target_properties(GLTF PROPERTIES 
  IMPORTED_LOCATION "${GLTF_LIBRARY_PATH}"
  INTERFACE_INCLUDE_DIRECTORIES "${GLTF_INCLUDE_DIR} ${RAPIDJSON_INCLUDE_DIR}"
  INTERFACE_LINK_LIBRARIES "${GLTF_LIBRARY_DIR}"
)

# cpp-LINQ
ExternalProject_Add(LINQ
  GIT_REPOSITORY https://github.com/coveo/LINQ.git
  GIT_TAG v2.0.2
  PREFIX LINQ
  INSTALL_DIR
  CMAKE_ARGS
  -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)

set(LINQ_INCLUDE_DIR          "${CMAKE_BINARY_DIR}/LINQ/src/LINQ/lib")

add_library(LIB_LINQ INTERFACE IMPORTED)
add_dependencies(LIB_LINQ LINQ)
set_target_properties(LIB_LINQ PROPERTIES 
  INTERFACE_INCLUDE_DIRECTORIES ${LINQ_INCLUDE_DIR}
)


# GSL
ExternalProject_Add(GSL
  GIT_REPOSITORY https://github.com/Microsoft/GSL.git
  GIT_TAG v1.0.0
  PREFIX GSL
  INSTALL_DIR
  CMAKE_ARGS
	-DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
)

set(GSL_INCLUDE_DIR           "${CMAKE_BINARY_DIR}/GSL/include")

add_library(LIB_GSL INTERFACE IMPORTED)
add_dependencies(LIB_GSL GSL)
set_target_properties(LIB_GSL PROPERTIES 
  INTERFACE_INCLUDE_DIRECTORIES ${GSL_INCLUDE_DIR}
)

# filesystem
ExternalProject_Add(FS
  GIT_REPOSITORY https://github.com/WonderMediaProductions/filesystem
  GIT_TAG maya2glTF
  PREFIX FS
  INSTALL_DIR
  CMAKE_ARGS
	-DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)

set(FS_INCLUDE_DIR            "${CMAKE_BINARY_DIR}/FS/src/FS")

add_library(LIB_FS INTERFACE IMPORTED)
add_dependencies(LIB_FS FS)
set_target_properties(LIB_FS PROPERTIES 
  INTERFACE_INCLUDE_DIRECTORIES ${FS_INCLUDE_DIR}
)

# maya2glTF
file(GLOB SOURCES "src/*.cpp" "src/*.h" "src/*.c")

add_library(${PROJECT_NAME} SHARED ${SOURCES})

include_directories(
  ${GLTF_INCLUDE_DIR}
  ${RAPIDJSON_INCLUDE_DIR}
  ${MAYA_INCLUDE_DIR}
  ${LINQ_INCLUDE_DIR}
  ${GSL_INCLUDE_DIR}
  ${FS_INCLUDE_DIR}
)

link_directories(
  ${MAYA_LIBRARY_DIR}
  ${GLTF_LIBRARY_DIR}
)


if (MSVC)
  # TODO: Test!
  add_custom_target(PCH "echo no PCH target")
  set_target_properties(${PROJECT_NAME} PROPERTIES COMPILE_FLAGS "/Yuexternals.h")
  set_source_files_properties(src/externals.cpp PROPERTIES COMPILE_FLAGS "/Ycexternals.h")
  set_source_files_properties(src/mikktspace.c  PROPERTIES COMPILE_FLAGS "/Y-")
else()
  add_clang_pch(PCH "src/externals.h" "src/externals.cpp" "${MAYA_COMPILE_DEFINITIONS}")
  use_clang_pch(${PROJECT_NAME} PCH)
  set_source_files_properties(src/mikktspace.c PROPERTIES COMPILE_FLAGS COMPILE_FLAGS "")
endif()

add_dependencies(PCH_trigger
  LIB_GLTF
  LIB_LINQ
  LIB_FS
  LIB_GSL
)

add_dependencies(${PROJECT_NAME}
  PCH
)

target_link_libraries(${PROJECT_NAME} ${MAYA_LIBRARIES} LIB_GLTF)

# Get the current working branch
execute_process(
  COMMAND git rev-parse --abbrev-ref HEAD
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  OUTPUT_VARIABLE GIT_BRANCH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Get the current tag
execute_process(
  COMMAND git describe --tags --abbrev=0
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  OUTPUT_VARIABLE GIT_TAG
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Get the latest abbreviated commit hash of the working branch
execute_process(
  COMMAND git log -1 --format=%h
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  OUTPUT_VARIABLE GIT_COMMIT_HASH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

configure_file(
  ${CMAKE_SOURCE_DIR}/version.inl.in
  ${CMAKE_BINARY_DIR}/generated/version.inl
)

configure_file(
  ${CMAKE_SOURCE_DIR}/version.mel.in
  ${CMAKE_BINARY_DIR}/generated/maya2glTF_Version.mel
)

include_directories(${CMAKE_BINARY_DIR}/generated)

if(MSVC)
  
  add_custom_command(TARGET maya2glTF POST_BUILD 
    COMMAND XCOPY /Y "$<SHELL_PATH:$<TARGET_FILE:maya2glTF>>" "$<SHELL_PATH:$ENV{USERPROFILE}/Documents/maya/${MAYA_VERSION}/plug-ins/>"
    COMMAND xcopy /y "$<SHELL_PATH:${PROJECT_SOURCE_DIR}/maya/scripts/maya2glTF*.mel>" "$<SHELL_PATH:$ENV{USERPROFILE}/Documents/maya/${MAYA_VERSION}/scripts/>"
    COMMAND xcopy /y /s /i "$<SHELL_PATH:${PROJECT_SOURCE_DIR}/maya/renderData/*.*>" "$<SHELL_PATH:$ENV{USERPROFILE}/Documents/maya/maya2glTF/PBR/>"
  )

elseif(APPLE)

  install (
    TARGETS maya2glTF 
    DESTINATION "/Users/Shared/Autodesk/maya/${MAYA_VERSION}/plug-ins/"
  )
  
  install (
    DIRECTORY "${PROJECT_SOURCE_DIR}/maya/scripts/" 
    DESTINATION "/Users/Shared/Autodesk/maya/scripts"
    FILES_MATCHING PATTERN "maya2glTF*.mel"
  )

  install (
    DIRECTORY "${CMAKE_BINARY_DIR}/generated/" 
    DESTINATION "/Users/Shared/Autodesk/maya/scripts"
    FILES_MATCHING PATTERN "maya2glTF*.mel"
  )

  install (
    DIRECTORY "${PROJECT_SOURCE_DIR}/maya/renderData/"
    DESTINATION "/Users/Shared/Autodesk/maya/maya2glTF/PBR"
  )

endif()

MAYA_PLUGIN(${PROJECT_NAME})
