using GPUAcceleratedTracking, DrWatson, ProgressMeter
@quickactivate "GPUAcceleratedTracking"


allparams = Dict(
    "num_samples" => 2 .^ (11:15),
    "num_ants" => [4],
    "num_correlators" => [3],
    "algorithm" => ["pure", "cplx", "cplx_multi"]
)

dicts = dict_list(allparams)

@showprogress 0.5 "Benchmarking reduction algorithms (pure vs cplx vs cplx_multi)" for (_, d) in enumerate(dicts)
    benchmark_results = run_reduction_benchmark(d)
    @tagsave(
        datadir("benchmarks/reduction", savename("Reduction", d, "jld2")), 
        benchmark_results
    )
end