cmake_minimum_required(VERSION 3.0.0)
project(Bitonic_sort VERSION 0.1.0)

set(CMAKE_BUILD_TYPE Release)

set(CMAKE_CXX_FLAGS "-O3")

find_package(OpenCL REQUIRED)
find_package(Boost 1.40 COMPONENTS program_options REQUIRED)

add_executable(Bitonic_sort main.cpp)
add_executable(Tests test.cpp ./src/Sort_test.cpp)

target_link_libraries(Bitonic_sort OpenCL::OpenCL)
target_link_libraries(Tests OpenCL::OpenCL)

target_link_libraries(Tests Boost::program_options)

target_compile_features(Tests PRIVATE cxx_std_17)

