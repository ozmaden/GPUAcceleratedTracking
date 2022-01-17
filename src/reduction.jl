# Reduction per Harris #3
function reduce_3(
    accum,
    input,
    num_samples,
)
    # define needed incides
    threads_per_block = blockDim().x
    block_idx = blockIdx().x
    thread_idx = threadIdx().x
    sample_idx = (block_idx - 1) * threads_per_block + thread_idx

    # allocate the shared memory for the partial sum
    shmem = @cuDynamicSharedMem(Float32, threads_per_block)

    # each thread loads one element from global to shared memory
    if sample_idx <= num_samples
        shmem[thread_idx] = input[sample_idx]
    end

    # wait until all finished
    sync_threads() 

    # do (partial) reduction in shared memory
    s::UInt32 = threads_per_block ÷ 2
    while s != 0 
        sync_threads()
        if thread_idx - 1 < s
            shmem[thread_idx] += shmem[thread_idx + s]
        end
        
        s ÷= 2
    end

    # first thread returns the result of reduction to global memory
    if thread_idx == 1
        accum[blockIdx().x] = shmem[1]
    end

    return nothing
end

# Complex reduction per Harris #3
function reduce_cplx_3(
    accum_re,
    accum_im,
    input_re,
    input_im,
    num_samples,
)
    # define needed incides
    threads_per_block = iq_offset = blockDim().x
    block_idx = blockIdx().x
    thread_idx = threadIdx().x
    sample_idx = (block_idx - 1) * threads_per_block + thread_idx

    # allocate the shared memory for the partial sum
    # double the memory for complex values, accessed via
    # iq_offset
    shmem = @cuDynamicSharedMem(Float32, (2 * threads_per_block))

    # each thread loads one element from global to shared memory
    if sample_idx <= num_samples
        shmem[thread_idx + 0 * iq_offset] = input_re[sample_idx]
        shmem[thread_idx + 1 * iq_offset] = input_im[sample_idx]
    end

    # wait until all finished
    sync_threads() 

    # do (partial) reduction in shared memory
    s::UInt32 = threads_per_block ÷ 2
    while s != 0 
        sync_threads()
        if thread_idx - 1 < s
            shmem[thread_idx + 0 * iq_offset] += shmem[thread_idx + 0 * iq_offset + s]
            shmem[thread_idx + 1 * iq_offset] += shmem[thread_idx + 1 * iq_offset + s]
        end
        
        s ÷= 2
    end

    # first thread returns the result of reduction to global memory
    if thread_idx == 1
        accum_re[blockIdx().x] = shmem[1 + 0 * iq_offset]
        accum_im[blockIdx().x] = shmem[1 + 1 * iq_offset]
    end

    return nothing
end

# Complex reduction per Harris #3, multicorrelator, multiantenna
function reduce_cplx_multi_3(
    accum_re,
    accum_im,
    input_re,
    input_im,
    num_samples,
    num_ants::NumAnts{NANT},
    correlator_sample_shifts::SVector{NCOR, Int64}
) where {NANT, NCOR}
    # define needed incides
    threads_per_block = iq_offset = blockDim().x
    block_idx = blockIdx().x
    thread_idx = threadIdx().x
    sample_idx = (block_idx - 1) * threads_per_block + thread_idx

    # allocate the shared memory for the partial sum
    # double the memory for complex values, accessed via
    # iq_offset
    shmem = @cuDynamicSharedMem(Float32, (2 * threads_per_block, NANT, NCOR))

    # each thread loads one element from global to shared memory
    if sample_idx <= num_samples
        for antenna_idx = 1:NANT
            for corr_idx = 1:NCOR
                shmem[thread_idx + 0 * iq_offset, antenna_idx, corr_idx] = input_re[sample_idx, antenna_idx, corr_idx]
            	shmem[thread_idx + 1 * iq_offset, antenna_idx, corr_idx] = input_im[sample_idx, antenna_idx, corr_idx]
            end
        end
    end

    # wait until all finished
    sync_threads() 

    # do (partial) reduction in shared memory
    s::UInt32 = threads_per_block ÷ 2
    while s != 0 
        sync_threads()
        if thread_idx - 1 < s
            for antenna_idx = 1:NANT
                for corr_idx = 1:NCOR
                    shmem[thread_idx + 0 * iq_offset, antenna_idx, corr_idx] += shmem[thread_idx + 0 * iq_offset + s, antenna_idx, corr_idx]
                    shmem[thread_idx + 1 * iq_offset, antenna_idx, corr_idx] += shmem[thread_idx + 1 * iq_offset + s, antenna_idx, corr_idx]
                end
            end
        end
        
        s ÷= 2
    end

    # first thread returns the result of reduction to global memory
    if thread_idx == 1
        for antenna_idx = 1:NANT
            for corr_idx = 1:NCOR
                accum_re[blockIdx().x, antenna_idx, corr_idx] = shmem[1 + 0 * iq_offset, antenna_idx, corr_idx]
                accum_im[blockIdx().x, antenna_idx, corr_idx] = shmem[1 + 1 * iq_offset, antenna_idx, corr_idx]
            end
        end
    end

    return nothing
end