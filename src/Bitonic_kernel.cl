
#define TRUE 1
#define FALSE 0

#define T int
#define LOC_SIZE 2

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

void merge_increase(__global T* glob_arr, __local T* buf, int size){

    copy_to_local(buf, glob_arr, size);
    int mono_size = size / 2;

    __local T* first_arr = buf;
    __local T* second_arr = buf + mono_size; 

    int first_it  = 0, second_it = 0, glob_it = 0;

    while (first_it != mono_size && second_it != mono_size){

        if (first_arr[first_it] < second_arr[mono_size - second_it - 1]){

            glob_arr[glob_it] = first_arr[first_it];
            first_it++;
        } else{

            glob_arr[glob_it] = second_arr[mono_size - second_it - 1];
            second_it++;
        }

        glob_it++;
    }

    if (first_it != mono_size){

        copy_to_global(glob_arr + glob_it, first_arr + first_it, mono_size - first_it);
    } else{

        while (second_it != mono_size){

            glob_arr[glob_it] = second_arr[mono_size - second_it];
            second_it++;
            glob_it++;
        }
    }

    copy_to_global(glob_arr, buf, size);
}

void merge_decrease(__global T* glob_arr, __local T* buf, int size){

    copy_to_local(buf, glob_arr, size);
    int mono_size = size / 2;

    __local T* first_arr = buf;
    __local T* second_arr = buf + mono_size;

    int first_it  = 0, second_it = 0, glob_it = 0;

    while (first_it != mono_size && second_it != mono_size){

        if (first_arr[mono_size - first_it - 1] > second_arr[second_it]){

            glob_arr[glob_it] = first_arr[mono_size - first_it - 1];
            first_it++;
        } else{

            glob_arr[glob_it] = second_arr[second_it];
            second_it++;
        }

        glob_it++;
    }

    if (second_it != mono_size){

        copy_to_global(glob_arr + glob_it, second_arr + second_it, mono_size - second_it);
    } else{

        while (first_it != mono_size){

            glob_arr[glob_it] = first_arr[mono_size - first_it];
            first_it++;
            glob_it++;
        }
    }

    copy_to_global(glob_arr, buf, size);
}

void merge(__global T* glob_arr, __local T* buf, int size, int increase){

    if (increase){

        merge_increase(glob_arr, buf, size);
    } else{

        merge_decrease(glob_arr, buf, size);
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
    //--------------------------------------

    int num_of_iter = num_of_iter_(arr_size, loc_arr_size), bitonic_size = loc_arr_size; //каждый тред отвечает за память размером loc_arr_size
    int left_arr_pos, right_arr_pos, increase;//bitonic_size - размер битонической последовательности
    unsigned threads_per_bitonic = 1;

    for (int i = 0; i < num_of_iter; i++){

        threads_per_bitonic = 1; 
        
        for (int split_num = i; split_num > 0; split_num--){

            threads_per_bitonic = threads_per_bitonic << split_num;

            left_arr_pos = (glob_id / threads_per_bitonic) * bitonic_size + (glob_id % threads_per_bitonic) * loc_arr_size; //возможно надо на 2 разделить
            right_arr_pos = left_arr_pos + bitonic_size / 2;
            increase = !((glob_id / threads_per_bitonic) % 2);

            split(glob_arr + left_arr_pos, glob_arr + right_arr_pos, loc_arr_size, increase);
            //--------------------------------------
        }

        increase = !((glob_arr_pos / bitonic_size) % 2);//!!!!!!!!!!!!!!!!!!!
        merge(glob_arr + glob_arr_pos, loc_arr + loc_arr_pos, loc_arr_size, increase);
        //--------------------------------------
        bitonic_size *= 2;
    }

    copy_to_global(glob_arr + glob_arr_pos, loc_arr + loc_arr_pos, loc_arr_size);
}