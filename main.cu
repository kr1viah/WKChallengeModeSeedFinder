#include <iostream>
#include <cuda_runtime.h>
#include <vector>
#include "rng.cuh"
#include "lp-rng.cu"
#include "hp-rng.cu"

__device__
bool shouldStop = false;

__device__
uint32_t hash = 0;


__device__ int compareLoadouts(loadout hp_loadout, loadout lp_loadout) {
    // Compare everything inline, no separate function
    int equal = -1;

    // ints
    if (hp_loadout.character        != lp_loadout.character)        equal = 0;
    if (hp_loadout.abilityCharacter != lp_loadout.abilityCharacter) equal = 1;

    // doubles with epsilon
    if (fabs(hp_loadout.abilityLevel - lp_loadout.abilityLevel) > 0.0001) equal = 2;

    // array of ints
    for (int i = 0; i < 8; ++i) {
        if (hp_loadout.itemCounts[i] != lp_loadout.itemCounts[i]) {
            equal = 2+i;
            break;
        }
    }

    // more doubles and ints
    if (fabs(hp_loadout.startTime - lp_loadout.startTime) > 0.001) equal = 10;
    if (hp_loadout.colorState != lp_loadout.colorState)            equal = 11;
    if (fabs(hp_loadout.intensity - lp_loadout.intensity) > 0.001) equal = 12;

    return equal;
}

__global__
void bruteForce() {
    int totalThreads = blockDim.x * gridDim.x;
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int64_t i = idx;
    loadout lploadout = lp_get_results(0);
    for (;i < 4294967296;i = i + totalThreads) {
        lploadout = lp_get_results(i);
        if (true) { // insert actual condition here

            // // check high precision to make sure
            // we dont need to do this anymore, I checked and lp and hp differ
            // at most by 0.0001 (see compareLoadouts above)
            
            if (compareLoadouts(get_results(i), lploadout) == -1) {
                //  shouldStop = true;
                //  hash = i;
            } else {
                 printf("lp doesn't match hp in seed %lld! Please let me (kr1v) know! %d\n", i, compareLoadouts(get_results(i), lploadout));
            }
            // shouldStop = true;
            // hash = i;
        }
        if (shouldStop) {
            return;
        }
    }
}

extern "C" {
__declspec(dllexport) unsigned int startBruteForce() {

    bruteForce<<<1024,256>>>();

    uint32_t h_hash;

    // Copy winning hash to host memory
    cudaMemcpyFromSymbol(&h_hash, hash, sizeof(uint32_t), 0, cudaMemcpyDeviceToHost);

    return h_hash;
}

}