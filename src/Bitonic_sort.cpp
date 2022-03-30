#include "headers/Bitonic_sort.h"
#include <iostream>
#include <limits>
#include <ctime>

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
        CL_CONTEXT_PLATFORM, reinterpret_cast<cl_context_properties>(PId),
        0
    };

    return cl::Context(CL_DEVICE_TYPE_GPU, properties);
}




template <typename T>
BitonicSort<T>::BitonicSort(): platform_(get_GPU_platform()), 
                            context_(get_GPU_context(platform_())),
                            queue_(context_)
{
    cl::string platform_name = platform_.getInfo<CL_PLATFORM_NAME>();
    cl::string platform_profile = platform_.getInfo<CL_PLATFORM_PROFILE>();

    std::cout << "Platform:\n"
    << "-name: " << platform_name << '\n'
    << "-priofile" << platform_profile << std::endl;           
}

template <typename T>
void BitonicSort<T>::set_streams(std::istream& input, std::ostream& output){

    input_ = input;
    output_ = output;
}

template <typename T>
void BitonicSort<T>::read_array(int num_of_elems){

    cl::vector<T> tmp_buf(num_of_elems);
    unsigned long tmp_check_sum = 0;

    for (int i = 0; i < num_of_elems; i++){

        input_ >> tmp_buf[i];
        tmp_check_sum += std::hash<T>(tmp_buf[i]);
    }

    int degree_of_two = 1, new_size = 2;

    while (new_size < num_of_elems){

        new_size *= 2;
        degree_of_two++;
    }

    for (int i = 0; i < new_size - num_of_elems; i++){

        tmp_buf.push_back(std::numeric_limits<T>::max());
        tmp_check_sum += std::hash<T>(std::numeric_limits<T>::max());
    }

    std::swap(tmp_buf, input_arr);
    num_of_elems_ = num_of_elems;
    size_degree_of_two_ = degree_of_two;
    check_sum = tmp_check_sum;
}

template <typename T>
void BitonicSort<T>::print_array(){

    for (int i = 0; i < num_of_elems_; i++){

        output_ << sorted_arr[i] << std::endl;
    }
}

template <typename T>
double BitonicSort<T>::CPU_time(){

    cl::vector<T> tmp_buf;
    std::copy(input_arr.begin(), input_arr.end(), std::back_insert_iterator(tmp_buf));

    clock_t start = clock();
    sort_arr(tmp_buf);
    clock_t end = clock();

    std::swap(tmp_buf, sort_arr);

    return reinterpret_cast<double>(end - start) / CLOCKS_PER_SEC;
}