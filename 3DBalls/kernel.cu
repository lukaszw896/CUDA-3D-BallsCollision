#include <windows.h> 
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#include <GL\glut.h>
#include <time.h>
#include <stdlib.h>
#include <stdio.h>



#define N  10
#define GRAVITY 0.01
#define SPRINGINESS 0.95
#define RADIUS 0.08

bool isCalculatedOnGPU = true;
float colorStep = 1.0 / N;

int drawCallsCount = 0;
int measureCount = 1;
float timeSum = 0;
int refreshMillis = 35;


GLdouble eyeX = 0, eyeY = 0, eyeZ = 5;
GLdouble centerX = 0, centerY = 0, centerZ = 0;
GLdouble upX = 0, upY = 1, upZ = 0;

GLfloat xRotated = 45, yRotated = 45, zRotated = 45;

GLfloat ballsCoordinates[N * 3];
/*************    HOST   **************/

GLfloat speedTable_H[N * 3];
bool collisionMatrix_H[N * N];
int collisionSafetyCounter_H[N * N];

/*************   DEVICE   **************/

__device__ GLfloat speedTable_C[N * 3];
__device__ bool collisionMatrix[N * N];
__device__ int collisionSafetyCounter[N * N];

/*************FUNCTIONS*****************/
/***************************************/
void display(void);
void reshape(int x, int y);
void Timer(int value);

void initData();
float getRandomCord();
float getRandomSpeed();
double second();

void drawBackFace();
void drawFrontFace();
void drawLeftFace();
void drawRightFace();
void drawBottomFace();

void calculateNewPositionsCPU(float* ballsTable);
int detectCollisionCPU(GLfloat x, GLfloat y, GLfloat z, int ballNumber, GLfloat * ballTable);

void specialKeys(int key, int x, int y);

__global__ void initGpuData(float* speedTable);
cudaError_t sendDataToGPU();
__global__ void calculateNewPositions(float* ballsTable, float springiness, float radius);
cudaError_t sendAndCalculateCordsOnGPU(float* ballTable);
__device__ int detectCollision(GLfloat x, GLfloat y, GLfloat z, int ballNumber, GLfloat * ballTable);

/************   MAIN   *****************/
/***************************************/
int main(int argc, char **argv)
{
	initData();
	sendDataToGPU();

	glutInit(&argc, argv);
	glutInitWindowSize(1000, 1000);
	glutCreateWindow("3DBalls");
	glEnable(GL_DEPTH_TEST);
	glutDisplayFunc(display);
	glutSpecialFunc(specialKeys);
	glutReshapeFunc(reshape);
	glutTimerFunc(0, Timer, 0);
	glutMainLoop();
	return 0;
}


/******  Functions Declaration  ********/
/***************************************/
void display(void)
{

	glMatrixMode(GL_MODELVIEW);
	
	// clear the drawing buffer.
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	// clear the identity matrix.
	glLoadIdentity();
	glEnable(GL_BLEND);
	gluLookAt(eyeX, eyeY, eyeZ,
		centerX, centerY, centerZ,
		upX, upY, upZ);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	
	glRotatef(xRotated, 1.0, 0.0, 0.0);
	// rotation about Y axis
	glRotatef(yRotated, 0.0, 1.0, 0.0);
	// rotation about Z axis
	//glRotatef(zRotated, 0.0, 0.0, 1.0);
	

	for (int i = 0; i < N; i++){
		glPushMatrix();
		// traslate the draw by z = -4.0
		// Note this when you decrease z like -8.0 the drawing will looks far , or smaller.
		glTranslatef(ballsCoordinates[i*3], ballsCoordinates[i*3+1], ballsCoordinates[i*3+2]);
		// Red color used to draw.
		glColor3f(0.9, colorStep*i, 0.2);
		// changing in transformation matrix.
		
		glScalef(1.0, 1.0, 1.0);
		// built-in (glut library) function , draw you a sphere.
		glutWireSphere(RADIUS, 20, 20);
		glPopMatrix();
		// Flush buffers to screen
	}
	int currentAngle = (int)yRotated % 360;
	if (currentAngle < 0){
		currentAngle = 360 + currentAngle;
	}
	if ((45 >= currentAngle && currentAngle>=0) || (360 >= currentAngle && currentAngle>315)){
		drawBackFace();
		drawLeftFace();
		drawRightFace();
		drawFrontFace();
	}
	else if (45 < currentAngle && currentAngle <= 135){
		drawRightFace();
		drawFrontFace();
		drawBackFace();
		drawLeftFace();
			
	}
	else if (135 < currentAngle && currentAngle <= 225){
		drawFrontFace();
		drawRightFace();
		drawLeftFace();
		drawBackFace();
	}
	else{
		drawLeftFace();
		drawFrontFace();
		drawBackFace();
		drawRightFace();
	}
	glFlush();
	// sawp buffers called because we are using double buffering 
	// glutSwapBuffers();

	if (isCalculatedOnGPU){
		drawCallsCount++;
		cudaEvent_t start, stop;
		float time;
		cudaEventCreate(&start);
		cudaEventCreate(&stop);
		cudaEventRecord(start, 0);
		cudaError_t cudaStatus = sendAndCalculateCordsOnGPU(ballsCoordinates);
		cudaEventRecord(stop, 0);
		cudaEventSynchronize(stop);

		cudaEventElapsedTime(&time, start, stop);
		timeSum += time;
		if (drawCallsCount == 100)
		{
			printf("Average fps %f . Draw calls count: %d \n", (float)(1000 / (timeSum / 100)), (measureCount * 100));
			drawCallsCount = 0;
			measureCount++;
			timeSum = 0;
		}
	}
	else{
		drawCallsCount++;
		float hostTime;
		double startTime, stopTime, elapsed;
		startTime = second();
		calculateNewPositionsCPU(ballsCoordinates);
		stopTime = second();
		hostTime = (stopTime - startTime) * 1000;
		timeSum += hostTime;
		if (drawCallsCount == 100)
		{
			printf("Average fps %f . Draw calls count: %d \n", (float)(1000 / (timeSum / 100)), (measureCount * 100));
			drawCallsCount = 0;
			measureCount++;
			timeSum = 0;
		}
	}
}

void drawBackFace(){
	glBegin(GL_POLYGON);
	glColor4f(0, 0, 1, 0.5);
	glVertex3f(-1.0, -1.0, -1.0);       // P1
	glVertex3f(-1.0, 1.0, -1.0);       // P2
	glVertex3f(1.0, 1.0, -1.0);       // P3
	glVertex3f(1.0, -1.0, -1.0);       // P4
	glEnd();
}
void drawFrontFace(){
	glBegin(GL_POLYGON);
	glColor4f(0, 0, 1, 0.5);
	glVertex3f(-1.0, -1.0, 1.0);       // P1
	glVertex3f(-1.0, 1.0, 1.0);       // P2
	glVertex3f(1.0, 1.0, 1.0);       // P3
	glVertex3f(1.0, -1.0, 1.0);       // P4
	glEnd();
}
void drawLeftFace(){
	glBegin(GL_POLYGON);
	glColor4f(0, 0, 1, 0.5);
	glVertex3f(-1.0, -1.0, 1.0);       // P1
	glVertex3f(-1.0, 1.0, 1.0);       // P2
	glVertex3f(-1.0, 1.0, -1.0);       // P3
	glVertex3f(-1.0, -1.0, -1.0);       // P4
	glEnd();
}
void drawRightFace(){
	glBegin(GL_POLYGON);
	glColor4f(0, 0, 1, 0.5);
	glVertex3f(1.0, -1.0, 1.0);       // P1
	glVertex3f(1.0, 1.0, 1.0);       // P2
	glVertex3f(1.0, 1.0, -1.0);       // P3
	glVertex3f(1.0, -1.0, -1.0);       // P4
	glEnd();
}
void reshape(int x, int y)
{
	if (y == 0 || x == 0) return;
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(39.0, (GLdouble)x / (GLdouble)y, 0.6, 21.0);
	glMatrixMode(GL_MODELVIEW);
	glViewport(0, 0, x, y);  //Use the whole window for rendering
} 

void Timer(int value) {
	glutPostRedisplay();	// Post a paint request to activate display()
	glutTimerFunc(refreshMillis, Timer, 0); // subsequent timer call at milliseconds
}

void initData(){
	for (int i = 0; i < N; i++)
	{
		ballsCoordinates[i*3] = getRandomCord();
		ballsCoordinates[i*3 + 1] = getRandomCord();
		ballsCoordinates[i*3 + 2] = getRandomCord();
	}
	/*for (int i = 0; i < N * 3; i++){
		speedTable_C[i] = speedTable_H[i];
	}*/
	for (int i = 0; i < N; i++){
		speedTable_H[i * 3] = getRandomSpeed();
		speedTable_H[i * 3 + 1] = 0;
		speedTable_H[i * 3 + 2] = getRandomSpeed();
	}
}

float getRandomCord()
{
	int c = rand() % 4;
	float r = -1.0f + (rand() / (float)RAND_MAX * 2.0f);
	r = r + (c * 0.000005f);
	return r;
}

float getRandomSpeed()
{
	int c = rand() % 2;
	float a = 0.1f;
	float r = ((rand() / (float)RAND_MAX * a));
	if (c == 1)
		r = -r;
	return r;
}
double second()
{
	LARGE_INTEGER t;
	static double oofreq;
	static int checkedForHighResTimer;
	static BOOL hasHighResTimer;
	if (!checkedForHighResTimer) {
		hasHighResTimer = QueryPerformanceFrequency(&t);
		oofreq = 1.0 / (double)t.QuadPart;
		checkedForHighResTimer = 1;
	}
	if (hasHighResTimer) {
		QueryPerformanceCounter(&t);
		return (double)t.QuadPart * oofreq;
	}
	else {
		return (double)GetTickCount() / 1000.0;
	}
}

__global__ void initGpuData(float* speedTable){
	for (int i = 0; i < N * 3; i++){
		speedTable_C[i] = speedTable[i];
	}
	for (int i = 0; i < N*N; i++){
		collisionMatrix[i] = false;
		collisionSafetyCounter[i] = 0;
	}
}
cudaError_t sendDataToGPU(){
	float speedTable[3 * N];
	float* dev_speedTable = 0;
	cudaError_t cudaStatus;

	for (int i = 0; i < N; i++){
		speedTable[i * 3] = getRandomSpeed();
		speedTable[i * 3 + 1] = 0;
		speedTable[i * 3 + 2] = getRandomSpeed();
	}

	// Choose which GPU to run on, change this on a multi-GPU system.
	cudaStatus = cudaSetDevice(0);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		goto Error;
	}

	cudaStatus = cudaMalloc((void**)&dev_speedTable, 3 * N * sizeof(float));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	cudaStatus = cudaMemcpy(dev_speedTable, speedTable,3 * N * sizeof(float), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}

	initGpuData << <1, 1 >> >(dev_speedTable);

Error:
	cudaFree(dev_speedTable);

	return cudaStatus;
}

__global__ void calculateNewPositions(float* ballsTable){
	int k = blockIdx.x * blockDim.x + threadIdx.x;
	while (k < N){
		if (k < N) {			
			ballsTable[k * 3] += speedTable_C[k * 3];
			ballsTable[k * 3 + 1] += speedTable_C[k * 3 + 1];
			ballsTable[k * 3 + 2] += speedTable_C[k * 3 + 2];
			// Check if the ball exceeds the edges
			if (ballsTable[k * 3] > 1.0 - RADIUS){
				ballsTable[k * 3] = 1.0 - RADIUS;
				speedTable_C[k * 3] = -speedTable_C[k * 3] * SPRINGINESS;		
			}
			if (ballsTable[k * 3] < -1.0 + RADIUS){
				ballsTable[k * 3] = -1.0 + RADIUS;
				speedTable_C[k * 3] = -speedTable_C[k * 3] * SPRINGINESS;
			}
			if (ballsTable[k * 3 + 1] > 1.0 - RADIUS){
				ballsTable[k * 3 + 1] = 1.0 - RADIUS;
				speedTable_C[k * 3 + 1] = -speedTable_C[k * 3 + 1] * SPRINGINESS;
			}
			if (ballsTable[k * 3 + 1] < -1.0 + RADIUS){
				ballsTable[k * 3 + 1] = -1.0 + RADIUS;
				speedTable_C[k * 3 + 1] = -speedTable_C[k * 3 + 1] * SPRINGINESS;
			}			

			if (ballsTable[k * 3 + 2] > 1.0 - RADIUS){
				ballsTable[k * 3 + 2] = 1.0 - RADIUS;
				speedTable_C[k * 3 + 2] = -speedTable_C[k * 3 + 2] * SPRINGINESS;
			}
			if (ballsTable[k * 3 + 2] < -1.0 + RADIUS){
				ballsTable[k * 3 + 2] = -1.0 + RADIUS;
				speedTable_C[k * 3 + 2] = -speedTable_C[k * 3 + 2] * SPRINGINESS;
			}

			int ballDetected = detectCollision(ballsTable[k * 3], ballsTable[k * 3 + 1], ballsTable[k * 3 + 2], k, ballsTable);

			if (ballDetected != -1){
				float tmpSpeedX = speedTable_C[k * 3];
				float tmpSpeedY = speedTable_C[k * 3 + 1];
				float tmpSpeedZ = speedTable_C[k * 3 + 2];
				speedTable_C[k * 3] = speedTable_C[ballDetected * 3];
				speedTable_C[k * 3 + 1] = speedTable_C[ballDetected * 3 + 1];
				speedTable_C[k * 3 + 2] = speedTable_C[ballDetected * 3 + 2];
				speedTable_C[ballDetected * 3] = tmpSpeedX;
				speedTable_C[ballDetected * 3 + 1] = tmpSpeedY;
				speedTable_C[ballDetected * 3 + 2] = tmpSpeedZ;
			}
			//FRICTION
			if ((ballsTable[k * 3 + 1] < -1.0 + RADIUS + 0.0003) && (speedTable_C[k * 3 + 1] < 0.02)){
				speedTable_C[k * 3] *= 0.98;
				speedTable_C[k * 3 + 2] *= 0.98;
			}
			//gravity
			
			speedTable_C[k*3+1] -= GRAVITY;
			//tmpSpeedTableY[k] -= 0.01f;
		}
		k += blockDim.x * gridDim.x;
	}
}
cudaError_t sendAndCalculateCordsOnGPU(float* ballTable)
{
	float* dev_ballTable = 0;
	cudaError_t cudaStatus;

	// Choose which GPU to run on, change this on a multi-GPU system.
	cudaStatus = cudaSetDevice(0);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		goto Error;
	}
	cudaStatus = cudaMalloc((void**)&dev_ballTable, 3 * N * sizeof(float));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}
	cudaStatus = cudaMemcpy(dev_ballTable , ballTable, 3 * N * sizeof(float), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}
	calculateNewPositions << <100, 1000 >> >(dev_ballTable);

	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "addKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching addKernel!\n", cudaStatus);
		goto Error;
	}
	// Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(ballTable, dev_ballTable, 3 * N * sizeof(float), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}

	Error:
		cudaFree(dev_ballTable);

	return cudaStatus;
}

__device__ int detectCollision(GLfloat x, GLfloat y, GLfloat z, int ballNumber, GLfloat * ballTable){
	int collisionBall = -1;
	int num = ballNumber;
	for (int i = 0; i < N; i++){
		if (i != ballNumber){
			/*local*/
			GLfloat secondBallX = ballTable[i * 3];
			GLfloat secondBallY = ballTable[i * 3 + 1];
			GLfloat secondBallZ = ballTable[i * 3 + 2];
			GLfloat firstBallX = ballTable[ballNumber * 3];
			GLfloat firstBallY = ballTable[ballNumber * 3 + 1];
			GLfloat firstBallZ = ballTable[ballNumber * 3 + 2];
			GLfloat leftSide = (2 * RADIUS)*(2 * RADIUS);
			GLfloat rightSide = ((firstBallX - secondBallX)*(firstBallX - secondBallX) + (firstBallY - secondBallY)*(firstBallY - secondBallY)) + (firstBallZ - secondBallZ)*(firstBallZ - secondBallZ);
			/**/
			if (leftSide > rightSide)
			{
				//collisionBall = ballsMatrix[coordinateX + i][coordinateY + j];
				if (collisionMatrix[ballNumber + i*N] == false){
					collisionMatrix[ballNumber + i*N] = true;
					collisionMatrix[i + N * ballNumber] = true;
					collisionSafetyCounter[ballNumber + i*N] = 2;
					collisionSafetyCounter[i + N * ballNumber] = 2;
					return i;
				}
			}
			else{
				if (collisionSafetyCounter[ballNumber + i*N] > 0){
					collisionSafetyCounter[ballNumber + i*N] --;
					collisionSafetyCounter[i + N * ballNumber] --;
				}
				else{
					collisionMatrix[ballNumber + N * i] = false;
					collisionMatrix[i + N * ballNumber] = false;
				}
			}
		}
	}
	return -1;
}



/*********		CPU calculations		**************/
void calculateNewPositionsCPU(float* ballsTable){
	for(int k=0;k<N;k++){
			ballsTable[k * 3] += speedTable_H[k * 3];
			ballsTable[k * 3 + 1] += speedTable_H[k * 3 + 1];
			ballsTable[k * 3 + 2] += speedTable_H[k * 3 + 2];
			// Check if the ball exceeds the edges
			if (ballsTable[k * 3] > 1.0 - RADIUS){
				ballsTable[k * 3] = 1.0 - RADIUS;
				speedTable_H[k * 3] = -speedTable_H[k * 3] * SPRINGINESS;
			}
			if (ballsTable[k * 3] < -1.0 + RADIUS){
				ballsTable[k * 3] = -1.0 + RADIUS;
				speedTable_H[k * 3] = -speedTable_H[k * 3] * SPRINGINESS;
			}
			if (ballsTable[k * 3 + 1] > 1.0 - RADIUS){
				ballsTable[k * 3 + 1] = 1.0 - RADIUS;
				speedTable_H[k * 3 + 1] = -speedTable_H[k * 3 + 1] * SPRINGINESS;
			}
			if (ballsTable[k * 3 + 1] < -1.0 + RADIUS){
				ballsTable[k * 3 + 1] = -1.0 + RADIUS;
				speedTable_H[k * 3 + 1] = -speedTable_H[k * 3 + 1] * SPRINGINESS;
			}

			if (ballsTable[k * 3 + 2] > 1.0 - RADIUS){
				ballsTable[k * 3 + 2] = 1.0 - RADIUS;
				speedTable_H[k * 3 + 2] = -speedTable_H[k * 3 + 2] * SPRINGINESS;
			}
			if (ballsTable[k * 3 + 2] < -1.0 + RADIUS){
				ballsTable[k * 3 + 2] = -1.0 + RADIUS;
				speedTable_H[k * 3 + 2] = -speedTable_H[k * 3 + 2] * SPRINGINESS;
			}

			int ballDetected = detectCollisionCPU(ballsTable[k * 3], ballsTable[k * 3 + 1], ballsTable[k * 3 + 2], k, ballsTable);

			if (ballDetected != -1){
				float tmpSpeedX = speedTable_H[k * 3];
				float tmpSpeedY = speedTable_H[k * 3 + 1];
				float tmpSpeedZ = speedTable_H[k * 3 + 2];
				speedTable_H[k * 3] = speedTable_H[ballDetected * 3];
				speedTable_H[k * 3 + 1] = speedTable_H[ballDetected * 3 + 1];
				speedTable_H[k * 3 + 2] = speedTable_H[ballDetected * 3 + 2];
				speedTable_H[ballDetected * 3] = tmpSpeedX;
				speedTable_H[ballDetected * 3 + 1] = tmpSpeedY;
				speedTable_H[ballDetected * 3 + 2] = tmpSpeedZ;
			}
			//FRICTION
			if ((ballsTable[k * 3 + 1] < -1.0 + RADIUS + 0.0003) && (speedTable_H[k * 3 + 1] < 0.02)){
				speedTable_H[k * 3] *= 0.98;
				speedTable_H[k * 3 + 2] *= 0.98;
			}
			//gravity

			speedTable_H[k * 3 + 1] -= GRAVITY;
			//tmpSpeedTableY[k] -= 0.01f;
		}
}

int detectCollisionCPU(GLfloat x, GLfloat y, GLfloat z, int ballNumber, GLfloat * ballTable){
	int collisionBall = -1;
	int num = ballNumber;
	for (int i = 0; i < N; i++){
		if (i != ballNumber){
			/*local*/
			GLfloat secondBallX = ballTable[i * 3];
			GLfloat secondBallY = ballTable[i * 3 + 1];
			GLfloat secondBallZ = ballTable[i * 3 + 2];
			GLfloat firstBallX = ballTable[ballNumber * 3];
			GLfloat firstBallY = ballTable[ballNumber * 3 + 1];
			GLfloat firstBallZ = ballTable[ballNumber * 3 + 2];
			GLfloat leftSide = (2 * RADIUS)*(2 * RADIUS);
			GLfloat rightSide = ((firstBallX - secondBallX)*(firstBallX - secondBallX) + (firstBallY - secondBallY)*(firstBallY - secondBallY)) + (firstBallZ - secondBallZ)*(firstBallZ - secondBallZ);
			/**/
			if (leftSide > rightSide)
			{
				//collisionBall = ballsMatrix[coordinateX + i][coordinateY + j];
				if (collisionMatrix_H[ballNumber + i*N] == false){
					collisionMatrix_H[ballNumber + i*N] = true;
					collisionMatrix_H[i + N * ballNumber] = true;
					collisionSafetyCounter_H[ballNumber + i*N] = 2;
					collisionSafetyCounter_H[i + N * ballNumber] = 2;
					return i;
				}
			}
			else{
				if (collisionSafetyCounter_H[ballNumber + i*N] > 0){
					collisionSafetyCounter_H[ballNumber + i*N] --;
					collisionSafetyCounter_H[i + N * ballNumber] --;
				}
				else{
					collisionMatrix_H[ballNumber + N * i] = false;
					collisionMatrix_H[i + N * ballNumber] = false;
				}
			}
		}
	}
	return -1;
}

void specialKeys(int key, int x, int y) {

	//  Right arrow - increase rotation by 5 degree
	if (key == GLUT_KEY_RIGHT){
		yRotated += 1;
	}
		
	//  Left arrow - decrease rotation by 5 degree
	else if (key == GLUT_KEY_LEFT){
		yRotated -= 1;
	}
	else if (key == GLUT_KEY_UP){
		xRotated += 1;
	}

	else if (key == GLUT_KEY_DOWN){
		xRotated -= 1;
	}
	else if (key == GLUT_KEY_PAGE_UP){
		eyeZ += 0.05;
	}
	else if (key == GLUT_KEY_PAGE_DOWN){
		eyeZ -= 0.05;
	}

	//  Request display update
	//glutPostRedisplay();

}

