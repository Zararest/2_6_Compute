#include "./src/headers/Bitonic_sort.hpp"
#include <fstream>

int main(){

    std::ifstream input("../bin/input");
    BitonicSort<int> app{input};

    app.read_array(20);
    app.CPU_time();
    app.check_sorted_arr();
    
    app.load_kernel("../src/Bitonic_kernel.cl");

    std::pair<double, double> GPU_time;

    try{

        GPU_time = app.GPU_time();
    } catch(cl::Error& err){

        std::cerr << "OpenCl:" << err.err() << ":" << err.what() << std::endl;
    }

    std::cout << "On GPU: " << GPU_time.first << std::endl;
    std::cout << "Calc time: " << GPU_time.second << std::endl;

    app.print_array();
}