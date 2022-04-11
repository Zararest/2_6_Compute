
#define TRUE 1
#define FALSE 0

#define MERGE(sign) do{                                                         \
                        int mono_size = size / 2;                               \
                        T* first_arr = buf;                                     \
                        T* second_arr = buf + mono_size;                        \
                                                                                \
                        int first_it  = 0, second_it = 0, glob_it = 0;          \
                                                                                \
                        while (first_it != mono_size && second_it != mono_size){\
                                                                                \
                            if (first_arr[first_it] sign second_arr[second_it]){\
                                                                                \
                                glob_arr[glob_it] = first_arr[first_it];        \
                                first_it++;                                     \
                            } else{                                             \
                                                                                \
                                glob_arr[glob_it] = second_arr[second_it];      \
                                second_it++;                                    \
                            }                                                   \
                                                                                \
                            glob_it++;                                          \
                        }                                                       \
                                                                                \
                        for (; first_it < mono_size; first_it++, glob_it++){    \
                                                                                \
                            glob_arr[glob_it] = first_arr[first_it];            \
                        }                                                       \
                                                                                \
                        for (; second_it < mono_size; second_it++, glob_it++){  \
                                                                                \
                            glob_arr[glob_it] = second_arr[second_it];          \
                        }                                                       \
                    } while(0)   

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

void sort_local_arr(__local T* arr, int size, int increase){ //shell sort

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

void reverse_copy_to_local(__local T* dest_arr, __global T* src_arr, int size){

    for (int i = 0; i < size; i++){

        dest_arr[i] = src_arr[size - 1 - i];
    }
}

void merge(__global T* glob_arr, __local T* buf, int size, int increase){ //ok

    if (max(glob_arr[0], glob_arr[size - 1]) > min(glob_arr[size / 2 - 1], glob_arr[size / 2])){

        if (increase){

            copy_to_local(buf, glob_arr + size / 2, size / 2);
            reverse_copy_to_local(buf + size / 2, glob_arr, size / 2);

            MERGE(<);
        } else{

            reverse_copy_to_local(buf, glob_arr + size / 2, size / 2);
            copy_to_local(buf + size / 2, glob_arr, size / 2);

            MERGE(>);
        }

        return;
    }

    if (min(glob_arr[0], glob_arr[size - 1]) < max(glob_arr[size / 2 - 1], glob_arr[size / 2])){

        if (increase){

            reverse_copy_to_local(buf, glob_arr + size / 2, size / 2);
            copy_to_local(buf + size / 2, glob_arr, size / 2);

            MERGE(<);
        } else{

            copy_to_local(buf, glob_arr + size / 2, size / 2);
            reverse_copy_to_local(buf + size / 2, glob_arr, size / 2);

            MERGE(>);
        }

        return;
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

int num_of_iter_(int arr_size, int bitonic_size){

    int result = 0;
    while (arr_size > bitonic_size){

        bitonic_size *= 2;
        result++;
    }

    return result + 1;
}

void init_data(__global T* glob_arr, __local T* loc_arr, int size){

    copy_to_local(loc_arr, glob_arr, size);

    sort_local_arr(loc_arr, size / 2, TRUE);
    sort_local_arr(loc_arr + size / 2, size / 2, FALSE);

    copy_to_global(glob_arr, loc_arr, size);
}

__kernel void Bitonic_sort(__global T* glob_arr, int arr_size, int loc_arr_size){ //loc_arr_size считается в Т 

    int glob_id = get_global_id(0);
    int loc_id = get_local_id(0);

    __local T loc_arr[LOC_SIZE];

    int loc_arr_pos = loc_id * loc_arr_size, glob_arr_pos = glob_id * loc_arr_size;

    init_data(glob_arr + glob_arr_pos, loc_arr + loc_arr_pos, loc_arr_size);
    barrier(CLK_GLOBAL_MEM_FENCE);

    int num_of_iter = num_of_iter_(arr_size, loc_arr_size); //каждый тред отвечает за память размером loc_arr_size
    int left_arr_pos, right_arr_pos, increase;//bitonic_size - размер битонической последовательности
    unsigned threads_per_bitonic = 1, bitonic_size = loc_arr_size;
    
    for (int i = 0; i < num_of_iter; i++){
        
        for (int split_num = i; split_num > 0; split_num--){ //тут размер битонической сортировки в 2 раза больше чем локальный размер
            
            bitonic_size = loc_arr_size << split_num;
            threads_per_bitonic = 1 << split_num;
            left_arr_pos = (glob_id / threads_per_bitonic) * bitonic_size + (glob_id % threads_per_bitonic) * loc_arr_size / 2; //возможно надо на 2 разделить
            right_arr_pos = left_arr_pos + bitonic_size / 2;
            increase = !((glob_id / threads_per_bitonic) % 2);

            split(glob_arr + left_arr_pos, glob_arr + right_arr_pos, loc_arr_size / 2, increase); //тут сигфолт
            barrier(CLK_GLOBAL_MEM_FENCE);
        }

        increase = !((glob_arr_pos / bitonic_size) % 2);
        merge(glob_arr + glob_arr_pos, loc_arr + loc_arr_pos, loc_arr_size, increase);
        barrier(CLK_GLOBAL_MEM_FENCE);
    }
    
    copy_to_global(glob_arr + glob_arr_pos, loc_arr + loc_arr_pos, loc_arr_size);
}