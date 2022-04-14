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

#define XOR(A, B)   ((A) | (B)) & (!(A) | !(B))                        

#define IF_SPLIT_INCREASE (id / threads_per_bitonic) % 2 == 0
#define IF_BITONIC_INCREASE ((initial_pos + i * buf_size) % new_bitonic_size) < (new_bitonic_size / 2) 

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

void split_local(__local T* arr, int from, int to, bool increase){

    int middle = (to - from + 1) / 2;

    for (int i = 0; i < middle; i++){

        if (increase ? (arr[from + i] > arr[from + middle + i]) : (arr[from + i] < arr[from + middle + i])){

            T tmp = arr[from + i];
            arr[from + i] = arr[from + middle + i];
            arr[from + middle + i] = tmp;
        }
    }
}

void make_mono(__local T* arr, int from, int to, bool increase){

    int bitonic_seq_size = to - from + 1, cur_pos;

    while (bitonic_seq_size >= 2){
        
        cur_pos = from;
         
        for (int i = 0; i < (to - from + 1) / bitonic_seq_size; i++){
            
            split_local(arr, cur_pos, cur_pos + bitonic_seq_size - 1, increase);
            cur_pos += bitonic_seq_size;
        }

        bitonic_seq_size /= 2;
    } 
}

void bitonic_sort(__local T* arr, int arr_size, bool increase){

    int cur_pos, bitonic_size;

    for (int chunck_size = 2; chunck_size <= arr_size / 2; chunck_size *= 2){

        cur_pos = 0;

        for (int i = 0; i < arr_size / (chunck_size * 2); i++){

            make_mono(arr, cur_pos, cur_pos + chunck_size - 1, XOR(false, increase));
            cur_pos += chunck_size;
            make_mono(arr, cur_pos, cur_pos + chunck_size - 1, XOR(true, increase));
            cur_pos += chunck_size;
        }
    }

    make_mono(arr, 0, arr_size, XOR(false, increase));
}

void local_sort(__global T* arr, int arr_size, __local T* buf, int buf_size, int id, int num_of_merge_iter){

    int mearging_thread_num = LOC_SIZE / buf_size;
    if (id >= mearging_thread_num) return;

    int global_size_per_thread = arr_size / mearging_thread_num; //размер памяти, котору юдолжен инициализировать тред
    int initial_pos = global_size_per_thread * id;
    int num_of_iters = global_size_per_thread / buf_size; 

    int new_bitonic_size = buf_size << (num_of_merge_iter + 1); 

    __global T* cur_chunck_pos = arr + initial_pos;

    for (int i = 0; i < num_of_iters; i++){

        copy_to_local(buf, cur_chunck_pos, buf_size);
        bitonic_sort(buf, buf_size, true);
        copy_to_global(cur_chunck_pos, buf, buf_size);

        cur_chunck_pos += buf_size;
    }
}

void init_chunck(__global T* chunck, __local T* buf, int buf_size){

    int monoton_size = buf_size / 2;
    copy_to_local(buf, chunck, buf_size);

    sort_buf(buf, monoton_size, true);
    sort_buf(buf + monoton_size, monoton_size, false);
    //bitonic_sort(buf, monoton_size, true);
    //bitonic_sort(buf + monoton_size, monoton_size, false);

    copy_to_global(chunck, buf, buf_size);
}

void init_data(__global T* arr, int arr_size, __local T* buf, int buf_size, int id){
    
    int mearging_thread_num = LOC_SIZE / buf_size;
    if (id >= mearging_thread_num) return;

    int global_size_per_thread = arr_size / mearging_thread_num; //размер памяти, котору юдолжен инициализировать тред
    int initial_pos = global_size_per_thread * id;
    int num_of_iters = global_size_per_thread / buf_size;        //количество инициализаций на тред

    __global T* cur_chunck_pos = arr + initial_pos;

    for (int i = 0; i < num_of_iters; i++){

        init_chunck(cur_chunck_pos, buf, buf_size);
        cur_chunck_pos += buf_size;
    }
}

void split(__global T* left_arr, __global T* right_arr, int size, bool increase){
    
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

    init_data(arr, arr_size, buf, buf_size, id);            //размер начальных битонических - buf_size = 512
    barrier(CLK_GLOBAL_MEM_FENCE | CLK_LOCAL_MEM_FENCE);
    
    int num_of_iter = get_num_of_iter(arr_size, buf_size);

    for (int i = 0; i < num_of_iter; i++){
        
        for (int split_num = i; split_num > 0; split_num--){

            unsigned bitonic_size = buf_size << split_num;      //размер битонической, которую сейчас разбиваем
            unsigned threads_per_bitonic = 1 << split_num;

            int left_arr_pos = (id / threads_per_bitonic) * bitonic_size + (id % threads_per_bitonic) * (buf_size / 2);
            int right_arr_pos = left_arr_pos + bitonic_size / 2;
            
            split(arr + left_arr_pos, arr + right_arr_pos, buf_size / 2, IF_SPLIT_INCREASE);
            barrier(CLK_GLOBAL_MEM_FENCE | CLK_LOCAL_MEM_FENCE);
        }

        local_sort(arr, arr_size, buf, buf_size, id, i);         //после первого мерджа размер - 1024
        barrier(CLK_GLOBAL_MEM_FENCE | CLK_LOCAL_MEM_FENCE);
    }
}