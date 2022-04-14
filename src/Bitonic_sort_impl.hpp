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
void BitonicSort<T>::sort_arr(cl::vector<T>& arr, int size_degree_of_two){

    int input_size = std::pow(2, size_degree_of_two);

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
                            BitonicSort<T>(Config{get_max_WG_size()}, input, output)
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
    << "-max WG size " << get_max_WG_size() << '\n' 
    << "-cur WG size " << config.iteration_size << '\n' << std::endl; 
}

template <typename T>
void BitonicSort<T>::read_array(int num_of_elems){

    cl::vector<T> tmp_buf(num_of_elems);
    unsigned long tmp_check_sum = 0;

    for (int i = 0; i < num_of_elems; i++){

        input_ >> tmp_buf[i];
        tmp_check_sum += std::hash<T>{}(tmp_buf[i]);
    }

    int degree_of_two = 1, new_size = 2;

    while (new_size < num_of_elems){

        new_size *= 2;
        degree_of_two++;
    }

    for (int i = 0; i < new_size - num_of_elems; i++){

        tmp_buf.push_back(std::numeric_limits<T>::max());
        tmp_check_sum += std::hash<T>{}(std::numeric_limits<T>::max());
    }

    std::swap(tmp_buf, input_arr);
    num_of_elems_ = num_of_elems;
    size_degree_of_two = degree_of_two;
    check_sum = tmp_check_sum;
}

template <typename T>
void BitonicSort<T>::print_array(){

    int i = 0;

    for (auto it : sorted_arr){

        if (i >= num_of_elems_) return;
        i++;

        output_ << it << std::endl;
    }
}

template <typename T>
bool BitonicSort<T>::check_sorted_arr(){
    
    T prev;

    if (!sorted_arr.empty()){

        prev = sorted_arr[0];
    }

    unsigned long cur_check_sum = 0;
    
    for (auto it : sorted_arr){

        if (it < prev){

            std::cerr << "Wrong orderind:" 
            << prev << " > " << it << std::endl;

            return false;
        }

        prev = it;
        cur_check_sum += std::hash<T>{}(it);
    }

    if (cur_check_sum != check_sum){

        std::cerr << "Wrong check sum:"
        << cur_check_sum << " != " << check_sum << std::endl;

        return false;
    }

    return true;
}

template <typename T>
long BitonicSort<T>::CPU_time(){

    cl::vector<T> tmp_buf;
    std::copy(input_arr.begin(), input_arr.end(), std::back_insert_iterator<cl::vector<T>>(tmp_buf));

    clock_t start = clock();
    sort_arr(tmp_buf, size_degree_of_two);
    clock_t end = clock();

    std::swap(tmp_buf, sorted_arr);

    return (end - start) / 1000;
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

template <typename T>
int BitonicSort<T>::get_max_WG_size(){

    cl::Platform platform = get_GPU_platform();
    std::vector<cl::Device> devices; 
    platform.getDevices(CL_DEVICE_TYPE_GPU, &devices);
    int result = 0;

    for (auto it : devices){

        if (it.getInfo<CL_DEVICE_MAX_COMPUTE_UNITS>() > result){

            result = it.getInfo<CL_DEVICE_MAX_COMPUTE_UNITS>();
        }
    }

    return result;
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

    std::cout << "global it size " << calc_it_size() << std::endl
              << "local it size "  << calc_it_size() << std::endl
              << "arr size "       << input_arr.size() << std::endl 
              << "local arr size " << calc_local_mem_per_thread_size() / sizeof(T) << std::endl;

    GPU_start = std::chrono::high_resolution_clock::now();
    cl::Event event = funct(args, cl_arr, input_arr.size(), calc_local_mem_per_thread_size() / sizeof(T));
    event.wait();
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
bool BitonicSort<T>::if_bitonic(int bitonic_size){

}


