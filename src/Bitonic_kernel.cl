
#define TRUE 1
#define FALSE 0

#define SORT_BODY   do{                                                                                     \
                        int h;                                                                              \
                        for (h = 1; h <= size / 9; h = 3 * h + 1);                                          \
                                                                                                            \
                        for (; h > 0; h /= 3){                                                              \
                                                                                                            \
                            for (int i = h; i < size; i++){                                                 \
                                                                                                            \
                                int j = i;                                                                  \
                                T tmp = arr[i];                                                             \
                                                                                                            \
                                while (j >= h && (increase ? tmp < arr[j - h] : tmp > arr[j - h])){           \
                                                                                                            \
                                    arr[j] = arr[j - h];                                                    \
                                    j -= h;                                                                 \
                                }                                                                           \
                                arr[j] = tmp;                                                               \
                            }                                                                               \
                        }                                                                                   \
                    } while (0)

#define COPY_ARR    do{                                 \
                       for (int i = 0; i < size; i++){  \
                                                        \
                            dest_arr[i] = src_arr[i];   \
                        }                               \
                    } while (0)                             

void sort_global_arr(__global T* arr, int size, int increase){ //shell sort

    SORT_BODY;
}

void sort_local_arr(__local T* arr, int size, int increase){ //shell sort

    SORT_BODY;
}

void copy_to_local(__local T* dest_arr, __global T* src_arr, int size){

    COPY_ARR;
}

void copy_to_global(__global T* dest_arr, __local T* src_arr, int size){

    COPY_ARR;
}


void split(__local T* left_arr, __global T* right_arr, int size, int increase){

    for (int i = 0; i < size; i++){

        if (increase ? (right_arr[i] > left_arr[i]) : (right_arr[i] < left_arr[i])){

            T tmp = right_arr[i];
            right_arr[i] = left_arr[i];
            left_arr[i] = tmp;
        }
    }
}


__kernel void Bitonic_sort(__global T* glob_arr, int arr_size, int loc_arr_size){

    int glob_id = get_global_id(0);
    int loc_id = get_local_id(0);

    __local T loc_arr[LOC_SIZE];

    int loc_arr_pos = loc_id * loc_arr_size, glob_arr_pos = glob_id * loc_arr_size * 2;

    copy_to_local(loc_arr + loc_arr_pos, glob_arr + glob_arr_pos, loc_arr_size);
    sort_global_arr(glob_arr + glob_arr_pos + loc_arr_size, loc_arr_size, FALSE);
    sort_local_arr(loc_arr + loc_arr_pos, loc_arr_size, TRUE);

    int num_of_splits = 0, new_split_pos, increase;

    for (int chunck_size = loc_arr_size; chunck_size <= arr_size / 2; chunck_size *= 2){

        for (int i = num_of_splits - 1; i >= 0; i--){

            increase = glob_id % (2 << i);
            new_split_pos = loc_arr_size * i * 2; 
            split(loc_arr + loc_arr_pos, glob_arr + glob_arr_pos + new_split_pos, loc_arr_size, );
        }

        num_of_splits++;
    }

    //copy_to_global(glob_arr + glob_arr_pos, loc_arr + loc_arr_pos, loc_arr_size);
}