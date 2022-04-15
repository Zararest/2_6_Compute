#ifndef NEW_DATA
    #define T int
    #define LOC_SIZE 256
#endif

#define COPY_ARR    do{                                 \
                        for (int i = 0; i < size; i++){ \
                                                        \
                            dest_arr[i] = src_arr[i];   \
                        }                               \
                    } while (0)                            


void copy_to_local(__local T* dest_arr, __global T* src_arr, int size){

    COPY_ARR;
}

void copy_to_global(__global T* dest_arr, __local T* src_arr, int size){

    COPY_ARR;
}

void sort_buf(__local T* arr, int size, int increase){ //shell sort

    int h;                                                                              
    for (h = 1; h <= size / 9; h = 3 * h + 1);                                          
                                                                                        
    for (; h > 0; h /= 3){                                                              
                                                                                        
        for (int i = h; i < size; i++){                                                 
                                                                                        
            int j = i;                                                                  
            T tmp = arr[i];                                                             
                                                                                        
            while (j >= h && (increase ? tmp < arr[j - h] : tmp > arr[j - h])){        
                                                                                        
                arr[j] = arr[j - h];                                                    
                j -= h;                                                                 
            }                                                                           
            arr[j] = tmp;                                                               
        }                                                                               
    }
}

void split_local(__local T* arr, int size, bool increase){

    for (int i = 0; i < size / 2; i++){

        if (increase && (arr[i] > arr[i + size / 2]) || (!increase) && (arr[i] < arr[i + size / 2])){

            T tmp = arr[i];
            arr[i] = arr[i + size / 2];
            arr[i + size / 2] = tmp;
        }
    }
}

void make_mono(__local T* arr, int arr_size, bool increase){

    for (int bitonic_size = arr_size; bitonic_size > 1; bitonic_size /= 2){

        for (int cur_pos = 0; cur_pos < arr_size; cur_pos += bitonic_size){

            split_local(arr + cur_pos, bitonic_size, increase);
        }
    }
}

void local_sort(__global T* arr, __local T* buf, int buf_size, int bitonic_size){

    int id = get_local_id(0);
    int sorting_threads_num = LOC_SIZE / buf_size;
    if (id >= sorting_threads_num) return;

    int arr_size = get_local_size(0) * buf_size;
    int responsible_memory_size = arr_size / sorting_threads_num;
    int pos = id * responsible_memory_size;
    int threads_per_new_bitonic = (bitonic_size * 2) / buf_size;

    for (int shift = 0; shift < responsible_memory_size; shift += buf_size){

        bool increase = (pos / buf_size + shift / buf_size) % threads_per_new_bitonic < (threads_per_new_bitonic / 2);

        copy_to_local(buf, arr + pos + shift, buf_size);
        make_mono(buf, buf_size, increase);
        copy_to_global(arr + pos + shift, buf, buf_size);
    }
}

void split(__global T* left_arr, __global T* right_arr, int size, bool increase){
    
    for (int i = 0; i < size; i++){

        if (increase && (left_arr[i] > right_arr[i]) || (!increase) && (left_arr[i] < right_arr[i])){

            T tmp = right_arr[i];
            right_arr[i] = left_arr[i];
            left_arr[i] = tmp;
        }
    }
}

void merge_bitonics(__global T* arr, __local T* buf, int buf_size, int bitonic_size){

    int id = get_local_id(0);
    int threads_per_bitonic = bitonic_size / buf_size;            
    int threads_per_new_bitonic = threads_per_bitonic * 2;
    bool increase = (id % threads_per_new_bitonic) < (threads_per_new_bitonic / 2);
    
    for (int cur_bitonic_size = bitonic_size; cur_bitonic_size > buf_size; cur_bitonic_size /= 2){
        
        threads_per_bitonic = cur_bitonic_size / buf_size;
        int cur_pos = (id / threads_per_bitonic) * cur_bitonic_size + (id % threads_per_bitonic) * (buf_size / 2);
        
        split(arr + cur_pos, arr + cur_pos + cur_bitonic_size / 2, buf_size / 2, increase);
        barrier(CLK_GLOBAL_MEM_FENCE | CLK_LOCAL_MEM_FENCE);
    }
    
    local_sort(arr, buf, buf_size, bitonic_size);
}   

void init_chunck(__global T* chunck, __local T* buf, int buf_size){

    int monoton_size = buf_size / 2;
    copy_to_local(buf, chunck, buf_size);

    sort_buf(buf, monoton_size, true);
    sort_buf(buf + monoton_size, monoton_size, false);

    copy_to_global(chunck, buf, buf_size);
}

void init_data(__global T* arr, int arr_size, __local T* buf, int buf_size, int id){
    
    int mearging_thread_num = LOC_SIZE / buf_size;
    if (id >= mearging_thread_num) return;

    int global_size_per_thread = arr_size / mearging_thread_num;
    int initial_pos = global_size_per_thread * id;
    int num_of_iters = global_size_per_thread / buf_size;

    __global T* cur_chunck_pos = arr + initial_pos;

    for (int i = 0; i < num_of_iters; i++){

        init_chunck(cur_chunck_pos, buf, buf_size);
        cur_chunck_pos += buf_size;
    }
}

__kernel void Bitonic_sort(__global T* arr, int arr_size, int buf_size){
    
    int id = get_local_id(0);
    int mearging_thread_num = LOC_SIZE / buf_size;
    
    if (get_global_size(0) != get_local_size(0)){

        printf("Error: global size != local size\n");
        return;
    }
    
    __local T local_arr[LOC_SIZE];
    __local T* buf = NULL;

    if (id < mearging_thread_num){

        buf = local_arr + id * buf_size;
    }

    init_data(arr, arr_size, buf, buf_size, id);        
    barrier(CLK_GLOBAL_MEM_FENCE | CLK_LOCAL_MEM_FENCE);

    for (int bitonic_size = buf_size; bitonic_size <= arr_size; bitonic_size *= 2){
        
        merge_bitonics(arr, buf, buf_size, bitonic_size);
        barrier(CLK_GLOBAL_MEM_FENCE | CLK_LOCAL_MEM_FENCE);
    }
}