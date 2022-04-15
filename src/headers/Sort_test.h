#include "./Bitonic_sort.hpp"

#include <string>
#include <iostream>

class SortTest{

    std::string folder_path_;

    bool test_file(const std::string& file_name);

public:

    SortTest(const std::string& folder_path): folder_path_{folder_path}{}

    bool test();
};