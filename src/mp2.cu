#include <wb.h>

#define wbCheck(stmt)                                                          \
  do {                                                                         \
    cudaError_t err = stmt;                                                    \
    if (err != cudaSuccess) {                                                  \
      wbLog(ERROR, "Failed to run stmt ", #stmt);                              \
      wbLog(ERROR, "Got CUDA error ...  ", cudaGetErrorString(err));           \
      return -1;                                                               \
    }                                                                          \
  } while (0)

// Compute C = A * B

__global__ void matrixMultiply(float *A, float *B, float *C, int numARows,
                               int numAColumns, int numBRows, int numBColumns,
                               int numCRows, int numCColumns) {
  //@@ Insert code to implement matrix multiplication here
  int col = blockDim.x * blockIdx.x + threadIdx.x;
  int row = blockDim.y * blockIdx.y + threadIdx.y;

  if ( row < numCRows && col < numCColumns ){
    float val = 0.0;
    for ( int i = 0; i < numBRows; i++ )
      val += A[row * numAColumns + i] * B[i * numBColumns + col];
    C[row * numCColumns + col] = val;
  }
}
int main(int argc, char **argv) {
  wbArg_t args;
  float *hostA; // The A matrix
  float *hostB; // The B matrix
  float *hostC; // The output C matrix
  float *deviceA;
  float *deviceB;
  float *deviceC;
  int numARows;    // number of rows in the matrix A
  int numAColumns; // number of columns in the matrix A
  int numBRows;    // number of rows in the matrix B
  int numBColumns; // number of columns in the matrix B
  int numCRows;    // number of rows in the matrix C (you have to set this)
  int numCColumns; // number of columns in the matrix C (you have to set this)

  args = wbArg_read(argc, argv);

  wbTime_start(Generic, "Importing data and creating memory on host");
  hostA =
      ( float * )wbImport(wbArg_getInputFile(args, 0), &numARows, &numAColumns);
  hostB =
      ( float * )wbImport(wbArg_getInputFile(args, 1), &numBRows, &numBColumns);
  //@@ Set numCRows and numCColumns
  numCRows    = numARows;
  numCColumns = numBColumns;
  //@@ Allocate the hostC matrix
  wbTime_stop(Generic, "Importing data and creating memory on host");
  hostC = ( float * )malloc( numCRows * numCColumns * sizeof(float) );

  wbLog(TRACE, "The dimensions of A are ", numARows, " x ", numAColumns);
  wbLog(TRACE, "The dimensions of B are ", numBRows, " x ", numBColumns);
  wbLog(TRACE, "The dimensions of C are ", numCRows, " x ", numCColumns);

  wbTime_start(GPU, "Allocating GPU memory.");
  //@@ Allocate GPU memory here
  wbCheck(cudaMalloc( (void **) &deviceA, numARows * numAColumns * sizeof(float) ));
  wbCheck(cudaMalloc( (void **) &deviceB, numBRows * numBColumns * sizeof(float) ));
  wbCheck(cudaMalloc( (void **) &deviceC, numCRows * numCColumns * sizeof(float) ));

  wbTime_stop(GPU, "Allocating GPU memory.");

  wbTime_start(GPU, "Copying input memory to the GPU.");
  //@@ Copy memory to the GPU here
  wbCheck(cudaMemcpy(deviceA, hostA, numARows * numAColumns * sizeof(float), cudaMemcpyHostToDevice ));
  wbCheck(cudaMemcpy(deviceB, hostB, numBRows * numBColumns * sizeof(float), cudaMemcpyHostToDevice ));
  
  wbTime_stop(GPU, "Copying input memory to the GPU."); 
  //@@ Initialize the grid and block dimensions here 
  int THREAD_NUM = 32;
  dim3 dimBlock( THREAD_NUM, THREAD_NUM, 1 );
  dim3 dimGrid ( (numCColumns - 1) / THREAD_NUM + 1, (numCRows - 1) / THREAD_NUM + 1, 1 );

  wbLog(TRACE, "Ths grid dimension of kernal are ", dimGrid.x , "x", dimGrid.y, "x", dimGrid.z);
  wbLog(TRACE, "Ths block dimension of kernal are ", dimBlock.x , "x", dimBlock.y, "x", dimBlock.z);

  wbTime_start(Compute, "Performing CUDA computation");
  //@@ Launch the GPU Kernel here 
  matrixMultiply<<<dimGrid, dimBlock>>>(deviceA, deviceB, deviceC, numARows, numAColumns, 
                                        numBRows, numBColumns, numCRows, numCColumns);
  
  cudaDeviceSynchronize();
  wbTime_stop(Compute, "Performing CUDA computation");

  wbTime_start(Copy, "Copying output memory to the CPU");
  //@@ Copy the GPU memory back to the CPU here
  cudaMemcpy(hostC, deviceC, numCRows * numCColumns * sizeof(float), cudaMemcpyDeviceToHost );

  wbTime_stop(Copy, "Copying output memory to the CPU");

  wbTime_start(GPU, "Freeing GPU Memory");
  //@@ Free the GPU memory here
  wbCheck(cudaFree( deviceA ));
  wbCheck(cudaFree( deviceB ));
  wbCheck(cudaFree( deviceC ));

  wbTime_stop(GPU, "Freeing GPU Memory"); 

  wbSolution(args, hostC, numCRows, numCColumns); 

  free(hostA);
  free(hostB);
  free(hostC);

  return 0;
}
