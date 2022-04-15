#include "./src/headers/Bitonic_sort.hpp"
#include <fstream>

int main(){

    std::ifstream input("../bin/Huge_data");
    std::ofstream output("../bin/out");
    BitonicSort<int> app{input, output};

    app.read_array(4194304);
    std::cout << "CPU time: " << app.CPU_time() << std::endl;
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
    app.check_sorted_arr();
}