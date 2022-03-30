#pragma once

#include "../../lib/opencl.hpp"
#include <iostream>

template <typename T>
class BitonicSort{

    cl::Platform platform_;
    cl::Context  context_;
    cl::CommandQueue queue_;

    std::istream& input_ = std::cin;
    std::ostream& output_ = std::cout;

    unsigned long check_sum = 0;
    int num_of_elems_ = 0;
    int size_degree_of_two = 0;
    cl::vector<T> input_arr;
    cl::vector<T> sorted_arr;

    static cl::Platform get_GPU_platform();
    static cl::Context  get_GPU_context(cl_platform_id cur_platform);

    static void sort_arr(cl::vector<T>& arr);
    static void make_mono(cl::vector<T>& arr, int from, int to, bool increasing);
    static void split(cl::vector<T>& arr, int from, int to, bool increasing);
    
    bool check_sorted_arr();

public:

    BitonicSort();

    void set_streams(std::istream& input, std::ostream& output = std::cout);
    void read_array(int num_of_elems);
    void print_array();

    double CPU_time();
    std::pair<double, double> GPU_time();    
};