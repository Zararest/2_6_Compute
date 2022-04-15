#include "headers/Bitonic_sort.hpp"
#include <iostream>
#include <limits>
#include <ctime>
#include <cmath>
#include <cassert>
#include <fstream>
#include <sstream>
#include <chrono>
#include <unistd.h>
#include <algorithm>

template <typename T>
cl::Platform BitonicSort<T>::get_GPU_platform(){

    cl::vector<cl::Platform> platforms;
    cl::Platform::get(&platforms);

    for (auto p : platforms) {
    
        cl_uint numdevices = 0;
        ::clGetDeviceIDs(p(), CL_DEVICE_TYPE_GPU, 0, NULL, &numdevices);

        if (numdevices > 0) return cl::Platform(p); 
    }

    throw std::runtime_error("No platform selected");
}

template <typename T>
cl::Context BitonicSort<T>::get_GPU_context(cl_platform_id cur_platform){

    cl_context_properties properties[] = {
        CL_CONTEXT_PLATFORM, reinterpret_cast<cl_context_properties>(cur_platform),
        0
    };

    return cl::Context(CL_DEVICE_TYPE_GPU, properties);
}

template <typename T>
void BitonicSort<T>::split(cl::vector<T>& arr, int from, int to, bool increasing){
    
    int middle = (to - from + 1) / 2;

    for (int i = 0; i < middle; i++){

        if (increasing ? (arr[from + i] > arr[from + middle + i]) : (arr[from + i] < arr[from + middle + i])){

            std::swap(arr[from + i], arr[from + middle + i]);
        }
    }
}

template <typename T>
void BitonicSort<T>::make_mono(cl::vector<T>& arr, int from, int to, bool increasing){
    
    int bitonic_seq_size = to - from + 1, cur_pos;
    assert(bitonic_seq_size > 0);

    while (bitonic_seq_size >= 2){
        
        cur_pos = from;
         
        for (int i = 0; i < (to - from + 1) / bitonic_seq_size; i++){
            
            split(arr, cur_pos, cur_pos + bitonic_seq_size - 1, increasing);
            cur_pos += bitonic_seq_size;
        }

        bitonic_seq_size /= 2;
    }   
}

template <typename T>
void BitonicSort<T>::sort_arr(cl::vector<T>& arr){

    int input_size = calc_bitonic_arr_size(arr.size());

    if (arr.size() != input_size){

        std::cerr << "Invalid arr size:" << arr.size()
        << " expected: " << input_size << std::endl;
    }

    int cur_pos, bitonic_size;

    for (int chunck_size = 2; chunck_size <= input_size / 2; chunck_size *= 2){

        cur_pos = 0;

        for (int i = 0; i < input_size / (chunck_size * 2); i++){

            make_mono(arr, cur_pos, cur_pos + chunck_size - 1, true);
            cur_pos += chunck_size;
            make_mono(arr, cur_pos, cur_pos + chunck_size - 1, false);
            cur_pos += chunck_size;
        }
    }

    make_mono(arr, 0, input_size, true);
}

template <typename T>
void BitonicSort<T>::load_kernel(const std::string path){

    std::ifstream kernel_file{path};
    std::stringstream tmp_stream;

    if (!kernel_file.is_open()){

        std::cerr << "Can't read kernel" <<std::endl;
        return;
    }

    tmp_stream << kernel_file.rdbuf();
    kernel_file.close();
    
    std::string define_new_data = std::string("#define NEW_DATA\n");
    std::string local_mem_size = std::string("#define LOC_SIZE ") + std::to_string(config_.local_mem_size / sizeof(T)) + "\n";
    std::string data_type = std::string("#define T ") + config_.data_type + "\n";

    std::string tmp_str = define_new_data + local_mem_size + data_type + tmp_stream.str();
    std::swap(tmp_str, kernel_code);
}

template <typename T>
BitonicSort<T>::BitonicSort(std::istream& input, std::ostream& output):
                            BitonicSort<T>(Config{}, input, output)
{}

template <typename T>
BitonicSort<T>::BitonicSort(const Config& config, std::istream& input, std::ostream& output):
                            config_{config},
                            platform_(get_GPU_platform()), 
                            context_(get_GPU_context(platform_())),
                            queue_{context_, config_.propert},
                            input_{input},
                            output_{output}
{
    cl::string platform_name = platform_.getInfo<CL_PLATFORM_NAME>();
    cl::string platform_profile = platform_.getInfo<CL_PLATFORM_PROFILE>();
    
    std::cout << "Platform:\n"
    << "-name: " << platform_name << '\n'
    << "-priofile " << platform_profile << '\n' 
    << "-cur WG size " << config.iteration_size << '\n' << std::endl; 
}

template <typename T>
unsigned long BitonicSort<T>::calc_hash(cl_it<T> begin, cl_it<T> end){

    unsigned long result = 0;
    auto elems_hash = [&result](auto elem) mutable{ result += std::hash<T>{}(elem); };
    std::for_each(begin, end, elems_hash);

    return result;
}

template <typename T>
int BitonicSort<T>::calc_bitonic_arr_size(int cur_size){

    int new_size = 2;

    while (new_size < cur_size){

        new_size *= 2;
    }

    return new_size;
}

template <typename T>
void BitonicSort<T>::additional_fill_arr(cl::vector<T>& arr, int new_size, T elem){

    int prev_size = arr.size();
    arr.resize(new_size);
    
    std::fill(arr.begin() + prev_size, arr.end(), elem);
}

template <typename T>
void BitonicSort<T>::read_array(int num_of_elems){

    cl::vector<T> tmp_buf(num_of_elems);

    for (auto&& it : tmp_buf){

        input_ >> it; 
    }

    int cur_size = tmp_buf.size();
    additional_fill_arr(tmp_buf, calc_bitonic_arr_size(cur_size), std::numeric_limits<T>::max());
    unsigned long tmp_check_sum = calc_hash(tmp_buf.begin(), tmp_buf.end());

    std::swap(tmp_buf, input_arr);
    num_of_elems_ = num_of_elems;
    check_sum = tmp_check_sum;
}

template <typename T>
void BitonicSort<T>::print_array(){

    auto print = [&](auto elem) mutable { output_ << elem << std::endl; };
    std::for_each(sorted_arr.begin(), sorted_arr.end(), print);
}

template <typename T>
bool BitonicSort<T>::check_sorted_arr(){
    
    bool result = true;
    auto max_sort_iter = std::is_sorted_until(sorted_arr.begin(), sorted_arr.end());

    if (max_sort_iter != sorted_arr.end()){

        std::cerr << "Wrong ordering on: " << *max_sort_iter << std::endl;
        result = false;
    }

    unsigned long cur_check_sum = calc_hash(sorted_arr.begin(), sorted_arr.end());

    if (cur_check_sum != check_sum){

        std::cerr << "Wrong check sum: "
        << cur_check_sum << " != " << check_sum << std::endl;

        result = false;
    }

    return result;
}

template <typename T>
long BitonicSort<T>::CPU_time(){

    cl::vector<T> tmp_buf;
    std::copy(input_arr.begin(), input_arr.end(), std::back_insert_iterator<cl::vector<T>>(tmp_buf));

    std::chrono::high_resolution_clock::time_point start, end;
    
    start = std::chrono::high_resolution_clock::now();
    sort_arr(tmp_buf);
    end = std::chrono::high_resolution_clock::now();

    std::swap(tmp_buf, sorted_arr);

    return std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
}

template <typename T>
int BitonicSort<T>::calc_it_size(){

    #ifdef TEST
        return 2;
    #endif

    return config_.iteration_size; 
}

template <typename T>
int BitonicSort<T>::calc_local_mem_per_thread_size(){

    #ifdef TEST
        return 20 * sizeof(T);
    #endif
    
    return config_.local_mem_size / config_.merging_threads_num;
}

template<typename T>
cl::Event BitonicSort<T>::calc_on_GPU(cl::KernelFunctor<cl::Buffer, int, int>& funct, cl::EnqueueArgs& args, cl::Buffer& buf, int mem_per_thread){

    cl::Event event = funct(args, buf, input_arr.size(), mem_per_thread);
    event.wait();

    return event;
}

template <typename T>
std::pair<long, long> BitonicSort<T>::GPU_time(){

    cl::Buffer cl_arr(context_, CL_MEM_READ_WRITE, input_arr.size() * sizeof(T));
    cl::copy(queue_, input_arr.begin(), input_arr.end(), cl_arr);

    cl::Program program(context_, kernel_code, true);
    cl::KernelFunctor<cl::Buffer, int, int> funct(program, "Bitonic_sort");

    cl::NDRange global_range(calc_it_size());
    cl::NDRange local_range(calc_it_size());
    cl::EnqueueArgs args(queue_, global_range, local_range);

    cl_ulong GPU_calc_start, GPU_calc_end;
    std::chrono::high_resolution_clock::time_point GPU_start, GPU_end;
    long GPU_time = 0, GPU_calc_time = 0;

    GPU_start = std::chrono::high_resolution_clock::now();

    cl::Event event = calc_on_GPU(funct, args, cl_arr, calc_local_mem_per_thread_size() / sizeof(T));
    
    GPU_end = std::chrono::high_resolution_clock::now();
    GPU_time = std::chrono::duration_cast<std::chrono::milliseconds>(GPU_end - GPU_start).count();

    GPU_calc_start = event.getProfilingInfo<CL_PROFILING_COMMAND_QUEUED>();
    GPU_calc_end = event.getProfilingInfo<CL_PROFILING_COMMAND_END>();
    GPU_calc_time = (GPU_calc_end - GPU_calc_start) / 1'000'000;

    sorted_arr.resize(input_arr.size());
    cl::copy(queue_, cl_arr, sorted_arr.begin(), sorted_arr.end());

    return std::make_pair(GPU_time, GPU_calc_time);
}

template <typename T>
void BitonicSort<T>::find_bitonic(){

    bool increase = true;
    int sequence_start = 0;
    for (int i = 0; i < sorted_arr.size() - 1; i++){

        if (increase && sorted_arr[i] > sorted_arr[i + 1]){

            std::cout << "end of encrease [" << sequence_start << ", " << i << "] "
            << sorted_arr[i] << " > " << sorted_arr[i + 1] << std::endl;

            sequence_start = i + 1;
            increase = !increase;
        } else{

            if (!increase && sorted_arr[i] < sorted_arr[i + 1]){

                std::cout << "end of decrease [" << sequence_start << ", " << i << "] "
                << sorted_arr[i] << " < " << sorted_arr[i + 1] << std::endl;

                sequence_start = i + 1;
                increase = !increase;
            }
        }
    }
}


