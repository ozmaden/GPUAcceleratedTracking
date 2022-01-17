@testset "Reduction #3 per Harris" begin
    num_samples = 2500
    num_ants = 1
    num_correlators = 3
    correlator = EarlyPromptLateCorrelator(NumAnts(num_ants), NumAccumulators(num_correlators))
    correlator_sample_shifts = get_correlator_sample_shifts(GPSL1(), correlator, 2.5e6Hz, 0.5)
    input = StructArray{ComplexF32}(
        (
            CUDA.ones(Float32, (num_samples, num_ants, num_correlators)),
            CUDA.zeros(Float32, (num_samples, num_ants, num_correlators))
        )
    )
    threads_per_block = 256
    blocks_per_grid = cld(num_samples, threads_per_block)
    accum = StructArray{ComplexF32}(
        (
            CUDA.zeros(Float32, (blocks_per_grid, num_ants, num_correlators)),
            CUDA.zeros(Float32, (blocks_per_grid, num_ants, num_correlators))
        )
    )
    shmem_size = sizeof(ComplexF32) * threads_per_block
    for corr_idx = 1:num_correlators
        # re samples
        @cuda threads=threads_per_block blocks=blocks_per_grid shmem=shmem_size reduce_3(
            view(accum.re, :, :, corr_idx),
            view(input.re, :, :, corr_idx),
            num_samples
        )
        # im samples
        @cuda threads=threads_per_block blocks=blocks_per_grid shmem=shmem_size reduce_3(
            view(accum.im, :, :, corr_idx),
            view(input.im, :, :, corr_idx),
            num_samples
        )
    end
    for corr_idx = 1:num_correlators
        # re samples
        @cuda threads=threads_per_block blocks=1 shmem=shmem_size reduce_3(
            view(accum.re, :, :, corr_idx),
            view(accum.re, :, :, corr_idx),
            size(accum, 1)
        )
        # im samples
        @cuda threads=threads_per_block blocks=1 shmem=shmem_size reduce_3(
            view(accum.im, :, :, corr_idx),
            view(accum.im, :, :, corr_idx),
            size(accum, 1)
        )
    end
    accum_true = ComplexF32[num_samples num_samples num_samples]
    @test Array(accum)[1, :, :,] ≈ accum_true
end

@testset "Complex Reduction #3 per Harris" begin
    num_samples = 2500
    num_ants = 1
    num_correlators = 3
    correlator = EarlyPromptLateCorrelator(NumAnts(num_ants), NumAccumulators(num_correlators))
    correlator_sample_shifts = get_correlator_sample_shifts(GPSL1(), correlator, 2.5e6Hz, 0.5)
    input = StructArray{ComplexF32}(
        (
            CUDA.ones(Float32, (num_samples, num_ants, num_correlators)),
            CUDA.zeros(Float32, (num_samples, num_ants, num_correlators))
        )
    )
    threads_per_block = 256
    blocks_per_grid = cld(num_samples, threads_per_block)
    accum = StructArray{ComplexF32}(
        (
            CUDA.zeros(Float32, (blocks_per_grid, num_ants, num_correlators)),
            CUDA.zeros(Float32, (blocks_per_grid, num_ants, num_correlators))
        )
    )
    shmem_size = sizeof(ComplexF32) * threads_per_block
    for corr_idx = 1:num_correlators
        @cuda threads=threads_per_block blocks=blocks_per_grid shmem=shmem_size reduce_cplx_3(
            view(accum.re, :, :, corr_idx),
            view(accum.im, :, :, corr_idx),
            view(input.re, :, :, corr_idx),
            view(input.im, :, :, corr_idx),
            num_samples
        )
    end
    for corr_idx = 1:num_correlators
        @cuda threads=threads_per_block blocks=1 shmem=shmem_size reduce_cplx_3(
            view(accum.re, :, :, corr_idx),
            view(accum.im, :, :, corr_idx),
            view(accum.re, :, :, corr_idx),
            view(accum.im, :, :, corr_idx),
            size(accum, 1)
        )
    end
    accum_true = ComplexF32[num_samples num_samples num_samples]
    @test Array(accum)[1, :, :,] ≈ accum_true
end

@testset "Complex Multi Reduction #3 per Harris" begin
    num_samples = 2500
    num_ants = 1
    num_correlators = 3
    correlator = EarlyPromptLateCorrelator(NumAnts(num_ants), NumAccumulators(num_correlators))
    correlator_sample_shifts = get_correlator_sample_shifts(GPSL1(), correlator, 2.5e6Hz, 0.5)
    input = StructArray{ComplexF32}(
        (
            CUDA.ones(Float32, (num_samples, num_ants, num_correlators)),
            CUDA.zeros(Float32, (num_samples, num_ants, num_correlators))
        )
    )
    threads_per_block = 256
    blocks_per_grid = cld(num_samples, threads_per_block)
    accum = StructArray{ComplexF32}(
        (
            CUDA.zeros(Float32, (blocks_per_grid, num_ants, num_correlators)),
            CUDA.zeros(Float32, (blocks_per_grid, num_ants, num_correlators))
        )
    )
    shmem_size = sizeof(ComplexF32) * threads_per_block * num_ants * num_correlators
    @cuda threads=threads_per_block blocks=blocks_per_grid shmem=shmem_size reduce_cplx_multi_3(
        accum.re,
        accum.im,
        input.re,
        input.im,
        num_samples,
        NumAnts(num_ants),
        correlator_sample_shifts
    )
    @cuda threads=threads_per_block blocks=1 shmem=shmem_size reduce_cplx_multi_3(
        accum.re,
        accum.im,
        accum.re,
        accum.im,
        size(accum, 1),
        NumAnts(num_ants),
        correlator_sample_shifts
    )
    accum_true = ComplexF32[num_samples num_samples num_samples]
    @test Array(accum)[1, :, :,] ≈ accum_true
end