
#define INCREASE 1
#define DECREASE 0

#ifndef NEW_DATA
    #define T int
    #define LOC_SIZE 256
#endif

#define INCREASE_MERGE <
#define DECREASE_MERGE >

#define MERGE(sign) do{                                                         \
                        int mono_size = buf_size / 2;                           \
                        __local T* first_arr = buf;                             \
                        __local T* second_arr = buf + mono_size;                \
                                                                                \
                        int first_it  = 0, second_it = 0, glob_it = 0;          \
                                                                                \
                        while (first_it != mono_size && second_it != mono_size){\
                                                                                \
                            if (first_arr[first_it] sign second_arr[second_it]){\
                                                                                \
                                chunck[glob_it] = first_arr[first_it];          \
                                first_it++;                                     \
                            } else{                                             \
                                                                                \
                                chunck[glob_it] = second_arr[second_it];        \
                                second_it++;                                    \
                            }                                                   \
                                                                                \
                            glob_it++;                                          \
                        }                                                       \
                                                                                \
                        for (; first_it < mono_size; first_it++, glob_it++){    \
                                                                                \
                            chunck[glob_it] = first_arr[first_it];              \
                        }                                                       \
                                                                                \
                        for (; second_it < mono_size; second_it++, glob_it++){  \
                                                                                \
                            chunck[glob_it] = second_arr[second_it];            \
                        }                                                       \
                    } while(0)  

#define COPY_ARR    do{                                 \
                       for (int i = 0; i < size; i++){  \
                                                        \
                            dest_arr[i] = src_arr[i];   \
                        }                               \
                    } while (0)                             

#define IF_SPLIT_INCREASE !((id / threads_per_bitonic) % 2)
#define IF_MERGE_INCREASE ((initial_pos + i * buf_size) % new_bitonic_size) < (new_bitonic_size / 2) 

void copy_to_local(__local T* dest_arr, __global T* src_arr, int size){

    COPY_ARR;
}

void reverse_copy_to_local(__local T* dest_arr, __global T* src_arr, int size){

    for (int i = 0; i < size; i++){

        dest_arr[i] = src_arr[size - 1 - i];
    }
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

void merge_chunck(__global T* chunck, __local T* buf, int buf_size, int increase){
    
    if (chunck[0] < chunck[buf_size / 2 - 1] || chunck[buf_size / 2] > chunck[buf_size - 1]){
        
        if (increase == 1){
        
            copy_to_local(buf, chunck, buf_size / 2);
            reverse_copy_to_local(buf + buf_size / 2, chunck  + buf_size / 2, buf_size / 2);
            
            MERGE(INCREASE_MERGE);
        } else{

            copy_to_local(buf, chunck + buf_size / 2, buf_size / 2);
            reverse_copy_to_local(buf + buf_size / 2, chunck, buf_size / 2);
            
            MERGE(DECREASE_MERGE);
        }
    } else{
        
        if (increase == 1){

            copy_to_local(buf, chunck + buf_size / 2, buf_size / 2);
            reverse_copy_to_local(buf + buf_size / 2, chunck, buf_size / 2);
            
            MERGE(INCREASE_MERGE);
        } else{

            copy_to_local(buf, chunck, buf_size / 2);
            reverse_copy_to_local(buf + buf_size / 2, chunck  + buf_size / 2, buf_size / 2);
            
            MERGE(DECREASE_MERGE);
        }
    }
}

void merge(__global T* arr, int arr_size, __local T* buf, int buf_size, int id, int num_of_merge_iter){

    int mearging_thread_num = LOC_SIZE / buf_size;
    if (id >= mearging_thread_num) return;

    int global_size_per_thread = arr_size / mearging_thread_num; //размер памяти, котору юдолжен инициализировать тред
    int initial_pos = global_size_per_thread * id;
    int num_of_iters = global_size_per_thread / buf_size; 

    int new_bitonic_size = buf_size << (num_of_merge_iter + 1); 

    __global T* cur_chunck_pos = arr + initial_pos;

    for (int i = 0; i < num_of_iters; i++){
        
        merge_chunck(cur_chunck_pos, buf, buf_size, IF_MERGE_INCREASE);
        cur_chunck_pos += buf_size;

        if (id == 1){

            printf("bitonic size %i increase %i\n", new_bitonic_size, IF_MERGE_INCREASE);
        }
    }
}

void init_chunck(__global T* chunck, __local T* buf, int buf_size){

    int monoton_size = buf_size / 2;
    copy_to_local(buf, chunck, buf_size);

    sort_buf(buf               , monoton_size, INCREASE);
    sort_buf(buf + monoton_size, monoton_size, DECREASE);

    copy_to_global(chunck, buf, buf_size);
}

void init_data(__global T* arr, int arr_size, __local T* buf, int buf_size, int id){
    
    int mearging_thread_num = LOC_SIZE / buf_size;
    if (id >= mearging_thread_num) return;

    int global_size_per_thread = arr_size / mearging_thread_num; //размер памяти, котору юдолжен инициализировать тред
    int initial_pos = global_size_per_thread * id;
    int num_of_iters = global_size_per_thread / buf_size;         //количество инициализаций на тред

    __global T* cur_chunck_pos = arr + initial_pos;

    for (int i = 0; i < num_of_iters; i++){

        init_chunck(cur_chunck_pos, buf, buf_size);
        cur_chunck_pos += buf_size;
    }
}

void split(__global T* left_arr, __global T* right_arr, int size, int increase){
    
    for (int i = 0; i < size; i++){

        if (increase ? (right_arr[i] < left_arr[i]) : (right_arr[i] > left_arr[i])){  //теперь на возрастающие

            T tmp = right_arr[i];
            right_arr[i] = left_arr[i];
            left_arr[i] = tmp;
        }
    }
}

int get_num_of_iter(int arr_size, int bitonic_size){

    int result = 0;
    while (arr_size > bitonic_size){

        bitonic_size *= 2;
        result++;
    }

    return result + 1;
}

__kernel void Bitonic_sort(__global T* arr, int arr_size, int buf_size){
    
    int id = get_local_id(0);
    
    if (get_global_size(0) != get_local_size(0)){

        printf("Error: global size != local size\n");
        return;
    }

    __local T local_arr[LOC_SIZE];  //LOC_SIZE измеряется в T
    __local T* buf = local_arr + id * buf_size; //используется только тредами с id < mearging_thread_num

    init_data(arr, arr_size, buf, buf_size, id);
    barrier(CLK_GLOBAL_MEM_FENCE | CLK_LOCAL_MEM_FENCE);

    int num_of_iter = get_num_of_iter(arr_size, buf_size);

    for (int i = 0; i < num_of_iter; i++){
        
        for (int split_num = i; split_num > 0; split_num--){

            unsigned bitonic_size = buf_size << split_num;
            unsigned threads_per_bitonic = 1 << split_num;

            int left_arr_pos = (id / threads_per_bitonic) * bitonic_size + (id % threads_per_bitonic) * (buf_size / 2);
            int right_arr_pos = left_arr_pos + bitonic_size / 2;
            
            split(arr + left_arr_pos, arr + right_arr_pos, buf_size / 2, IF_SPLIT_INCREASE);
            barrier(CLK_GLOBAL_MEM_FENCE | CLK_LOCAL_MEM_FENCE);
            
        }
        
        merge(arr, arr_size, buf, buf_size, id, i);
        barrier(CLK_GLOBAL_MEM_FENCE | CLK_LOCAL_MEM_FENCE);
    }

    merge(arr, arr_size, buf, buf_size, id, num_of_iter - 1); //последний мердж надо сделать 
}