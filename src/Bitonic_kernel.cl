
#define INCREASE 1
#define DECREASE 0

#ifndef NEW_DATA
    #define T int
    #define LOC_SIZE 256
#endif

#define COPY_ARR    do{                                 \
                       for (int i = 0; i < size; i++){  \
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
    int num_of_iter = global_size_per_thread / buf_size;         //количество инициализаций на тред

    __global T* cur_chunck_pos = arr + initial_pos;

    for (int i = 0; i < num_of_iter; i++){

        init_chunck(cur_chunck_pos, buf, buf_size);
        cur_chunck_pos += buf_size;
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

            //----------------
            printf("split num %i\n", split_num);
            init_data(arr, arr_size, buf, buf_size, id);
            barrier(CLK_GLOBAL_MEM_FENCE | CLK_LOCAL_MEM_FENCE);
            //----
        }
        init_data(arr, arr_size, buf, buf_size, id);
        barrier(CLK_GLOBAL_MEM_FENCE | CLK_LOCAL_MEM_FENCE);

    }
}