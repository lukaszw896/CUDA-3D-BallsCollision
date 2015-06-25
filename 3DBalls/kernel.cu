
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#include <GL\glut.h>
#include <time.h>
#include <stdlib.h>
#include <stdio.h>

#define N  500

GLdouble eyeX = 0, eyeY = 0, eyeZ = 5;
GLdouble centerX = 0, centerY = 0, centerZ = 0;
GLdouble upX = 0, upY = 1, upZ = 0;

GLfloat xRotated = 0, yRotated = 0, zRotated = 0;
GLdouble radius = 0.01;

GLfloat ballsCoordinates[N * 3];

/*************FUNCTIONS*****************/
/***************************************/
void display(void);
void reshape(int x, int y);
void initData();
float getRandomCord();

void drawBackFace();
void drawFrontFace();
void drawLeftFace();
void drawRightFace();
void drawBottomFace();

void specialKeys(int key, int x, int y);

/************   MAIN   *****************/
/***************************************/
int main(int argc, char **argv)
{
	initData();

	glutInit(&argc, argv);
	glutInitWindowSize(1000, 1000);
	glutCreateWindow("Solid Sphere");
	glEnable(GL_DEPTH_TEST);
	glutDisplayFunc(display);
	glutSpecialFunc(specialKeys);
	glutReshapeFunc(reshape);
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
		glTranslatef(ballsCoordinates[i], ballsCoordinates[i+1], ballsCoordinates[i+2]);
		// Red color used to draw.
		glColor3f(0.9, 0.3, 0.2);
		// changing in transformation matrix.
		
		glScalef(1.0, 1.0, 1.0);
		// built-in (glut library) function , draw you a sphere.
		glutWireSphere(radius, 20, 20);
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

void initData(){
	for (int i = 0; i < N; i++)
	{
		ballsCoordinates[i] = getRandomCord();
		ballsCoordinates[i + 1] = getRandomCord();
		ballsCoordinates[i + 2] = getRandomCord();
	}
}

float getRandomCord()
{
	int c = rand() % 4;
	float r = -1.0f + (rand() / (float)RAND_MAX * 2.0f);
	r = r + (c * 0.000005f);
	return r;
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
	glutPostRedisplay();

}

