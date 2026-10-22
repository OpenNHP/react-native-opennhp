cmake_minimum_required(VERSION 3.22.1)
project(opennhpjni C)

set(NHP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}")
if(NOT EXISTS "${NHP_DIR}/libnhpagent.so")
  message(FATAL_ERROR "Missing OpenNHP library for ${ANDROID_ABI}: ${NHP_DIR}/libnhpagent.so")
endif()

add_library(opennhpjni SHARED nhp-jni.c)
target_link_directories(opennhpjni PRIVATE "${NHP_DIR}")
target_link_libraries(opennhpjni nhpagent)
target_link_options(opennhpjni PRIVATE
  "-Wl,-z,max-page-size=16384"
  "-Wl,-soname,libopennhpjni.so")
