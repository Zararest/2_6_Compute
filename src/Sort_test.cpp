#include "./headers/Sort_test.h"
#include <iostream>
#include <filesystem>
#include <vector>
#include <fstream>

bool SortTest::test_file(const std::string& file_name){

    bool result = true;
    std::string data_name = file_name;
    std::ifstream data{data_name};

    BitonicSort<int> sort{data};

    int data_size = 0;
    data >> data_size;

    sort.read_array(data_size);
    sort.load_kernel("../src/Bitonic_kernel.cl");
    sort.GPU_time();
    result = result & sort.check_sorted_arr();

    sort.CPU_time();
    result = result & sort.check_sorted_arr();

    return result;
}

bool SortTest::test(){

    bool result = true;
    std::filesystem::directory_iterator folder{folder_path_};

    for (auto&& it : folder){

        result = result & test_file(it.path());
    }

    return result;
}