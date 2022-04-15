#pragma once

#ifndef CL_HPP_TARGET_OPENCL_VERSION
#define CL_HPP_MINIMUM_OPENCL_VERSION 120
#define CL_HPP_TARGET_OPENCL_VERSION 120
#endif

#define CL_HPP_CL_1_2_DEFAULT_BUILD
#define CL_HPP_ENABLE_EXCEPTIONS

#include "../../lib/opencl.hpp"
#include <iostream>

template <typename T>
using cl_it = typename cl::vector<T>::iterator;

struct Config{

    int iteration_size = 256;
    int local_mem_size = 16384;    //размер локальной памяти
    int merging_threads_num = 8;   //количество потоков, работающих с ловакльной памятью
    std::string data_type = "int";
    cl::QueueProperties propert =
        cl::QueueProperties::Profiling | cl::QueueProperties::OutOfOrder;

    Config(int max_it_size): iteration_size{max_it_size}{}
    Config(){}
};

template <typename T>
class BitonicSort{

    Config config_;

    cl::Platform platform_;
    cl::Context  context_;
    cl::CommandQueue queue_;

    std::istream& input_ = std::cin;
    std::ostream& output_ = std::cout;

    unsigned long check_sum = 0;
    int num_of_elems_ = 0;
    cl::vector<T> input_arr;
    cl::vector<T> sorted_arr;
    std::string kernel_code;

    int calc_it_size();
    int calc_local_mem_per_thread_size();

    cl::Event calc_on_GPU(cl::KernelFunctor<cl::Buffer, int, int>& funct, cl::EnqueueArgs& args, cl::Buffer& buf, int mem_per_thread);

    static void additional_fill_arr(cl::vector<T>& arr, int new_size, T elem);
    static int calc_bitonic_arr_size(int cur_size);
    static unsigned long calc_hash(cl_it<T> begin, cl_it<T> end);

    static cl::Platform get_GPU_platform();
    static cl::Context  get_GPU_context(cl_platform_id cur_platform);

    static void sort_arr(cl::vector<T>& arr);
    static void make_mono(cl::vector<T>& arr, int from, int to, bool increasing);
    static void split(cl::vector<T>& arr, int from, int to, bool increasing);

public:

    BitonicSort(const Config& config, std::istream& input, std::ostream& output = std::cout);
    BitonicSort(std::istream& input, std::ostream& output = std::cout);

    void read_array(int num_of_elems);
    void print_array();
    bool check_sorted_arr();
    void load_kernel(const std::string path);

    long CPU_time();
    std::pair<long, long> GPU_time();    

    void find_bitonic();
};


#include "../Bitonic_sort_impl.hpp"