#include "./src/headers/Bitonic_sort.hpp"
#include <fstream>

int main(){

    std::ifstream input("../bin/input");
    BitonicSort<double> app{input};

    app.read_array(20);
    app.CPU_time();
    app.check_sorted_arr();
    app.print_array();
}