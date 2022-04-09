

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

void sort_global_arr(__global T* arr, int size, int increase){ //shell sort

    SORT_BODY;
}

void sort_local_arr(__local T* arr, int size, int increase){ //shell sort

    SORT_BODY;
}

__kernel void Bitonic_sort(__global T* glob_arr, int arr_size, int loc_arr_size){

    int glob_id = get_global_id(0);
    int loc_id = get_local_id(0);

    __local T loc_arr[LOC_SIZE];

    int loc_arr_pos = loc_id * loc_arr_size, glob_arr_pos = glob_id * loc_arr_size * 2;

    for (int i = 0; i < loc_arr_size; i++){

        loc_arr[loc_arr_pos + i] = glob_arr[glob_arr_pos + i];
    }

    
    sort_global_arr(glob_arr + glob_arr_pos, loc_arr_size, 1);
    sort_local_arr(loc_arr + loc_arr_pos, loc_arr_size, 0);

    for (int i = 0; i < loc_arr_size; i++){

        glob_arr[glob_arr_pos + i] = loc_arr[loc_arr_pos + i];
    }
}