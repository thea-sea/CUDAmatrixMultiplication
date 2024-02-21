/* Start Header *****************************************************************/

/*! \file kernel.cu

     \author Thea Sea, thea.sea, 2102348

     \par email: thea.sea@digipen.edu

     \date 19/2/2023

     \brief Copyright (C) 2024 DigiPen Institute of Technology.

  Reproduction or disclosure of this file or its contents without the prior written consent of DigiPen Institute of Technology is prohibited. */

/* End Header *******************************************************************/
/*
* Copyright 2024 Digipen.  All rights reserved.
*
* Please refer to the end user license associated
* with this source code for terms and conditions that govern your use of
* this software. Any use, reproduction, disclosure, or distribution of
* this software and related documentation outside the terms
* is strictly prohibited.
*
*/
#include <helper_cuda.h>
#include "helper.h"
//#include <cuda_runtime.h> //FIX __global__ and __shared__ undefined
#include <device_launch_parameters.h> //fix blockIdx undefined


//P and M column-major, N row-major
__global__ void matrixMultiply(FLOAT_TYPE* P,       //<! [out] and mxn matrix
	                            const FLOAT_TYPE* M, //<! [in] an mxk matrix
	                            const FLOAT_TYPE* N, //<! [in] an kxn matrix
	                            const int m, const int n, const int k) 
{
	// Shared memory for tiling input N array
	__shared__ FLOAT_TYPE N_s[TILE_WIDTH_RATIO_K][TILE_WIDTH_N];

	//do NOT change aboove
	//your code here
    int bx = blockIdx.x;
    int by = blockIdx.y;
    int tx = threadIdx.x;
    int ty = threadIdx.y;

    int Row = by * TILE_WIDTH_M + ty;
    int Col = bx * TILE_WIDTH_N + tx;

    FLOAT_TYPE P_reg[TILE_WIDTH_N];

    // Initialize P_reg to zero
    for (int i = 0; i < TILE_WIDTH_N; ++i) {
        P_reg[i] = 0.0;
    }

    // Loop over the input tiles
    for (int cnt = 0; cnt < (k - 1) / TILE_WIDTH_RATIO_K + 1; ++cnt) 
    {
        // Load the tile of N into shared memory
        int nIter = cnt * TILE_WIDTH_RATIO_K + tx;
        if (nIter < k) {
            N_s[ty][tx] = N[nIter * n + Col];
        }
        else {
            N_s[ty][tx] = 0.0;
        }

        __syncthreads();

        // Loop over elements inside the tile of N
        for (int i = 0; i < TILE_WIDTH_RATIO_K; ++i) {
            // Load tile of matrix M into register
            FLOAT_TYPE Mval = 0.0;
            if (Row < m && cnt * TILE_WIDTH_RATIO_K + i < k) {
                Mval = M[Row * k + cnt * TILE_WIDTH_RATIO_K + i];
            }

            // Loop over and update the output elements
            for (int j = 0; j < TILE_WIDTH_N; ++j) {
                if (Col + j < n) {
                    P_reg[j] += Mval * N_s[i][j];
                }
            }
        }

        __syncthreads();
    }

    // Store the output array variable to P elements
    for (int j = 0; j < TILE_WIDTH_N; ++j) {
        if (Row < m && Col + j < n) {
            P[Row * n + Col + j] = P_reg[j];
        }
    }
	
}

void matrixMultiplyGPU(FLOAT_TYPE* P,
	FLOAT_TYPE* M,
	FLOAT_TYPE* N,
	int numMRows,
	int numNColumns,
	int numMColumns)
{
	//@@ Initialize the grid and block dimensions here

	dim3 dimGrid((numMRows - 1) / TILE_WIDTH_M + 1, (numNColumns - 1) / TILE_WIDTH_N + 1);
	dim3 dimBlock(TILE_WIDTH_M, 1);
	matrixMultiply<<<dimGrid, dimBlock>>>(P, M, N, numMRows, numNColumns, numMColumns);

	getLastCudaError("matrixMultiply failed\n");
	cudaDeviceSynchronize();
}
