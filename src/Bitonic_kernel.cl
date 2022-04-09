#define T int
#define LOC_SIZE 10

__kernel void Bitonic_sort(__global T* arr, int arr_size, int local_mem_size){

    int glob_id = get_global_id(0);
    int loc_id = get_local_id(0);

    __local loc_arr[LOC_SIZE];


}