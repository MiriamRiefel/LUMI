/** LUMI eyes control software
 
 Lumi uses two LED matrix eyes of 96 x 80 pixels controlled over HDMI.
 the first 192x80 pixels of a screen are transferred to these Matrices.
 
 Libraries used:
 - GameControlPlus for Processing V3 (c) 2020 Peter Lager
 - Sound (processing standard)
 
 */

import org.gamecontrolplus.gui.*;
import org.gamecontrolplus.*;
import net.java.games.input.*;

ControlIO control;
Configuration config;
ControlDevice gpad;


import processing.sound.*;

SoundFile track;
SoundFile sample;
SoundFile sndYes, sndNo, sndAngry, sndStartup, sndShutdown, sndBreakdown, sndAlarm, sndCalculate, sndMove;

int screenWidth = 192;
int screenHeight = 80;
int eyeSize = 5*screenHeight/8;
int upperValue = eyeSize/2;

PImage eyeImg;

int imageNumber;
float pupilPosX, pupilPosY, pupilSize;
boolean blink;
boolean dilate;
int emotionalState;

//The image names in the folder that can be activated with the POV hat
String[] imageNames = {
   "lumi-battery.jpg",
   "lumi-classified.jpg",
   "lumi-map.jpg",
   "lumi-noconnection.jpg",
   "lumi-ok.jpg",
   "lumi-wait.jpg",
   "lumi-warning.jpg",
   "lumi-weather.jpg"
};

PImage[] images = new PImage[8];

public void setup() {
  size(400, 240);
  background(0);
  //fullScreen();
  background(0);
  eyeImg = loadImage("eye.png");
  
  // Map the image names to integers 1-8
  for (int i = 0; i < imageNames.length; i++) {
    images[i] = loadImage(imageNames[i]);
  }
  
  surface.setTitle("LUMI eye control");
  // Initialise the ControlIO
  control = ControlIO.getInstance(this);
  // Find a gamepad that matches the configuration file. To match with any
  // connected device remove the call to filter.
  //gpad = control.getMatchedDevice("gamepad_eyes");
  gpad = control.filter(GCP.GAMEPAD).getMatchedDevice("gamepad_eyes");
  if (gpad == null) {
    println("No suitable device configured");
    System.exit(-1); // End the program NOW!
  }

  sndAlarm = new SoundFile(this, "alarm.mp3");
  sndCalculate = new SoundFile(this, "calculate.mp3");
  sndYes = new SoundFile(this, "yes.mp3");
  sndNo = new SoundFile(this, "no.mp3");
  sndAngry = new SoundFile(this, "angry.mp3");
  sndBreakdown = new SoundFile(this, "breakdown.mp3");
  sndStartup = new SoundFile(this, "startup.mp3");
  sndShutdown = new SoundFile(this, "shutdown.mp3");
  sndMove = new SoundFile(this, "moving.mp3");
}
boolean playing;
public void getUserInput() {
  dilate = gpad.getButton("DILATE").pressed();
  pupilPosX =   map(gpad.getSlider("XPOS").getValue(), -1, 1, 0, screenWidth/2);
  pupilPosY =   map(gpad.getSlider("YPOS").getValue(), -1, 1, 0, screenHeight);
  blink = gpad.getButton("EYELID").pressed();
  imageNumber = gpad.getHat("POV").getPos();
  
  if (!sndAlarm.isPlaying() && gpad.getButton("B").pressed() && gpad.getButton("RT").pressed()) {
    println("sound alarm");
    sndAlarm.play();
  }
  if (!sndBreakdown.isPlaying() && gpad.getButton("Y").pressed() && gpad.getButton("RT").pressed()) {
    println("sound breakdown");
    sndBreakdown.play();
  }
  if (!sndStartup.isPlaying() && gpad.getButton("A").pressed() && gpad.getButton("RT").pressed()) {
    println("sound startup");
    sndStartup.play();
  }
    if (!sndShutdown.isPlaying() && gpad.getButton("X").pressed() && gpad.getButton("RT").pressed()) {
    println("sound shutdown");
    sndShutdown.play();
  }
    if (!sndYes.isPlaying() && gpad.getButton("A").pressed() && !gpad.getButton("RT").pressed()) {
    println("sound yes");
    sndYes.play();
  }
    if (!sndNo.isPlaying() && gpad.getButton("X").pressed() && !gpad.getButton("RT").pressed()) {
    println("sound no");
    sndNo.play();
  }
    if (!sndCalculate.isPlaying() && gpad.getButton("Y").pressed() && !gpad.getButton("RT").pressed()) {
    println("sound calculate");
    sndCalculate.play();
  }
  if (!sndAngry.isPlaying() && gpad.getButton("B").pressed() && !gpad.getButton("RT").pressed()) {
    println("sound angry");
    sndAngry.play();
  }
  if (!sndMove.isPlaying() && gpad.getButton("RS").pressed()) {
    println("sound moving");
    sndMove.play();
  }
  
  if (!sndYes.isPlaying() && !sndNo.isPlaying() &&
      !sndCalculate.isPlaying() && !sndAngry.isPlaying()) {
    emotionalState = 0; //neutral eyes
  }
  
  if (gpad.getButton("START").pressed()&& mode == 0){mode = 1;}
  if (gpad.getButton("BACK").pressed()&& mode == 1){mode = 0;}
}
float eyeX, prevEyeX, eyeY, prevEyeY;
int blinkTimer, nextBlinkTime, blinkDuration;
int eyeTimer, nextEyeTime, eyeOffsetX, eyeOffsetY;
int mode = 0;
int lastPupilSizeUpdateTime = 0;

//pupil constants
float minPupilSize = eyeSize * 0.32f;
float maxPupilSize = eyeSize * 0.7f;
float basePupilSize = eyeSize * 0.58f;
float dilationSpeed = 0.1f;
float contractionSpeed = 0.05f;
int lastEyeMoveTime = 0;
int eyeMoveThreshold = 200; // Time in milliseconds to consider eyes as focused
boolean isFocusing = false;
float focusingProbability = 0.4; // Variable to control the probability of being judged as focusing


public void draw() {
  getUserInput(); // Poll the input device
  background(127);
  fill(255);
  rect(0, 0, screenWidth, screenHeight);

  eyeX = (pupilPosX + eyeOffsetX)* 0.10 + prevEyeX * 0.90;
  eyeY = (pupilPosY + eyeOffsetY)* 0.10 + prevEyeY * 0.90;
  
  // Detect eye movement
  if (abs(eyeX - prevEyeX) > 0.5 || abs(eyeY - prevEyeY) > 0.5) {
    lastEyeMoveTime = millis(); // Update last eye move time
    isFocusing = false; // Not focusing
  } else {
    if (millis() - lastEyeMoveTime > eyeMoveThreshold) {
      isFocusing = random(1) < focusingProbability;
    }
  }
  
  if (millis()>blinkTimer+nextBlinkTime) {
    blinkTimer = millis();
    nextBlinkTime = (int)random(4000, 15000);
    blinkDuration = (int)random(5, 20);
  }
  if (blinkDuration>0) blinkDuration--;
  if (millis()>eyeTimer+nextEyeTime) {
    eyeTimer = millis();
    nextEyeTime = (int)random(1000, 4000);
    eyeOffsetX = (int)random(-15, 15);
    eyeOffsetY = (int)random(-2, 15);
  }

  prevEyeX = eyeX;
  prevEyeY = eyeY;
  
  if (blinkDuration>0) drawEyes((int)eyeX, (int)eyeY, true);
  else drawEyes((int)eyeX, (int)eyeY, blink);

  
  // Display an image prompted by the POV Hat (1-8)
  if (imageNumber != 0) {
    println(imageNames[imageNumber - 1]);
    int imgWidth = screenWidth/2;
    image(images[imageNumber-1], 0, 0, imgWidth, screenHeight);
    image(images[imageNumber-1], imgWidth, 0, imgWidth, screenHeight);
  }
  
  // Update pupil size based on focus and dilate button

    
  if (dilate) {
    pupilSize += (maxPupilSize - pupilSize) * dilationSpeed;
  }  
  
  else if (millis() - lastPupilSizeUpdateTime > ((int)random(100,500))) {
    lastPupilSizeUpdateTime = millis();
    if (isFocusing) {
      pupilSize += (minPupilSize - pupilSize) * contractionSpeed; // Enlarge pupils if focusing
    } else {
      pupilSize += (basePupilSize - pupilSize) * contractionSpeed; // Contract pupils if not focusing
    }
    
  pupilSize = constrain(pupilSize, minPupilSize, maxPupilSize);
  }
  noCursor();
}


public void drawEyes(int x, int y, boolean blink) {
  int lidMid = screenHeight/2;
  int dLid = 0;
  if (y>screenHeight) y = screenHeight;
  if (y<0) y = 0;
  if (x<eyeSize/2) x = eyeSize/2;
  if (x>(screenWidth/2-eyeSize/2)) x = (screenWidth/2-eyeSize/2);
  if(sndAngry.isPlaying()) {
    fill(255, 0, 0, 255);
    emotionalState = 4; //angry
  }
  else if (sndCalculate.isPlaying()) {
    fill(255,255,0,200);
    emotionalState = 3; //calculating
  }
  else if (sndNo.isPlaying()) {
    fill(0,0,255,200);
    emotionalState = 2; //sad eyes
  }
  else if (sndYes.isPlaying()) {
    fill(0,255,0,255);
    emotionalState = 1; //happy eyes
  }
  else if (sndBreakdown.isPlaying()) {
    fill(0,0,0,255);
    emotionalState = 5;
  }
  else {
    fill(0, 255, 100, 200);
    emotionalState = 0; //default=neutral
  }
  stroke(0);
  if(mode==0) blink = true;
  //  image(eyeImg, x-144, y-121);
  //  image(eyeImg, x+screenWidth/2-144, y-121);
  
  int eyeHeight; 
  if (emotionalState == 1) eyeHeight = y-10;
  else if (emotionalState == 2) eyeHeight = y+5;
  else eyeHeight = y;
  
  ellipse(x, eyeHeight, eyeSize, eyeSize);
  ellipse(x+screenWidth/2, eyeHeight, eyeSize, eyeSize);
  fill(0);
  ellipse(x, eyeHeight, pupilSize, pupilSize);
  ellipse(x+screenWidth/2, eyeHeight, pupilSize, pupilSize);
  
  if (blink == true) dLid = -eyeSize/10;
  else dLid = eyeSize/10;
  upperValue += dLid;
  if (upperValue>eyeSize/2) upperValue = eyeSize/2;
  if (upperValue<0) upperValue = 0;
  
  if (emotionalState == 1) { //happy
    //upleft
    beginShape();
    vertex(0, 0);
    vertex(screenWidth/2, 0);
    vertex(screenWidth/2, lidMid);
    bezierVertex(x+eyeSize/4, y-upperValue*1.5, x-eyeSize/4, y-upperValue*1.8, 0, lidMid);
    endShape();
  
    //lowleft
    beginShape();
    vertex(0, screenHeight);
    vertex(screenWidth/2, screenHeight);
    vertex(screenWidth/2, lidMid);
    bezierVertex(x+eyeSize/4, y+upperValue*0.5, x-eyeSize/4, y+upperValue, 0, lidMid);
    endShape();
  
    // Upper Right Eye (more pronounced curve)
    beginShape();
    vertex(screenWidth/2, 0);
    vertex(screenWidth, 0);
    vertex(screenWidth, lidMid);
    bezierVertex(x + screenWidth/2 + eyeSize/4, y - upperValue*1.8, x + screenWidth/2 - eyeSize/4, y - upperValue*1.5, screenWidth/2, lidMid);
    endShape();
  
    //lowright
    beginShape();
    vertex(screenWidth/2, screenHeight);
    vertex(screenWidth, screenHeight);
    vertex(screenWidth, lidMid);
    bezierVertex(x+screenWidth/2+eyeSize/4, y+upperValue, x+screenWidth/2-eyeSize/4, y+upperValue*0.5, screenWidth/2, lidMid);
    endShape();
    noStroke();
  }
  
  else if (emotionalState == 2) { //sad
  
  //upleft
    beginShape();
    vertex(0, 0);
    vertex(screenWidth/2, 0);
    vertex(screenWidth/2, lidMid*0.9);
    bezierVertex(x, y-upperValue, x-eyeSize/4, y+upperValue, 0, lidMid);
    endShape();
  
    //lowleft
    beginShape();
    vertex(0, screenHeight);
    vertex(screenWidth/2, screenHeight);
    vertex(screenWidth/2, lidMid*0.9);
    bezierVertex(x+eyeSize/4, y+upperValue, x-eyeSize/4, y+upperValue, 0, lidMid);
    endShape();
  
   //upright
    beginShape();
    vertex(screenWidth/2, 0);
    vertex(screenWidth, 0);
    vertex(screenWidth, lidMid);
    bezierVertex(x+screenWidth/2+eyeSize/4, y+upperValue, x+screenWidth/2-eyeSize/4, y-upperValue, screenWidth/2, lidMid*0.9);
    endShape();
  
    //lowright
    beginShape();
    vertex(screenWidth/2, screenHeight);
    vertex(screenWidth, screenHeight);
    vertex(screenWidth, lidMid);
    bezierVertex(x+screenWidth/2+eyeSize/4, y+upperValue, x+screenWidth/2-eyeSize/4, y+upperValue, screenWidth/2, lidMid*0.9);
    endShape();
    noStroke();
  }
  
  else if (emotionalState == 3) { //calculating
  
    //upleft
    beginShape();
    vertex(0, 0);
    vertex(screenWidth/2, 0);
    vertex(screenWidth/2, lidMid);
    bezierVertex(x+eyeSize/4, y-upperValue*1.5, x-eyeSize/4, y-upperValue*1.5, 0, lidMid);
    endShape();
  
    //lowleft
    beginShape();
    vertex(0, screenHeight);
    vertex(screenWidth/2, screenHeight);
    vertex(screenWidth/2, lidMid);
    bezierVertex(x+eyeSize/4, y+upperValue*1.5, x-eyeSize/4, y+upperValue*1.5, 0, lidMid);
    endShape();
  
    //upright
    beginShape();
    vertex(screenWidth/2, 0);
    vertex(screenWidth, 0);
    vertex(screenWidth, lidMid);
    bezierVertex(x + screenWidth/2 + eyeSize/4, y - upperValue*1.5, x + screenWidth/2 - eyeSize/4, y - upperValue*1.5, screenWidth/2, lidMid);
    endShape();
  
    //lowright
    beginShape();
    vertex(screenWidth/2, screenHeight);
    vertex(screenWidth, screenHeight);
    vertex(screenWidth, lidMid);
    bezierVertex(x+screenWidth/2+eyeSize/4, y+upperValue*1.5, x+screenWidth/2-eyeSize/4, y+upperValue*1.5, screenWidth/2, lidMid);
    endShape();
    noStroke();
  }
  
  else if (emotionalState == 4) { //angry
   
    //upleft
    beginShape();
    vertex(0, 0);
    vertex(screenWidth/2, 0);
    vertex(screenWidth/2, lidMid);
    bezierVertex(x+eyeSize/4, y+upperValue*2, x-eyeSize/6, y-upperValue*2, 0, lidMid);
    endShape();
  
    //lowleft
    beginShape();
    vertex(0, screenHeight);
    vertex(screenWidth/2, screenHeight);
    vertex(screenWidth/2, lidMid);
    bezierVertex(x+eyeSize/4, y+upperValue, x-eyeSize/4, y+upperValue, 0, lidMid);
    endShape();
  
   //upright
    beginShape();
    vertex(screenWidth/2, 0);
    vertex(screenWidth, 0);
    vertex(screenWidth, lidMid);
    bezierVertex(x+screenWidth/2+eyeSize/4, y-upperValue*2.5, x+screenWidth/2-eyeSize/2, y+upperValue*2, screenWidth/2, lidMid);
    endShape();
  
    //lowright
    beginShape();
    vertex(screenWidth/2, screenHeight);
    vertex(screenWidth, screenHeight);
    vertex(screenWidth, lidMid);
    bezierVertex(x+screenWidth/2+eyeSize/4, y+upperValue, x+screenWidth/2-eyeSize/4, y+upperValue, screenWidth/2, lidMid);
    endShape();
    noStroke();
  }
  
  else { //neutral
  
  //upleft
    beginShape();
    vertex(0, 0);
    vertex(screenWidth/2, 0);
    vertex(screenWidth/2, lidMid);
    bezierVertex(x+eyeSize/4, y-upperValue, x-eyeSize/4, y-upperValue, 0, lidMid);
    endShape();
  
    //lowleft
    beginShape();
    vertex(0, screenHeight);
    vertex(screenWidth/2, screenHeight);
    vertex(screenWidth/2, lidMid);
    bezierVertex(x+eyeSize/4, y+upperValue, x-eyeSize/4, y+upperValue, 0, lidMid);
    endShape();
  
   //upright
    beginShape();
    vertex(screenWidth/2, 0);
    vertex(screenWidth, 0);
    vertex(screenWidth, lidMid);
    bezierVertex(x+screenWidth/2+eyeSize/4, y-upperValue, x+screenWidth/2-eyeSize/4, y-upperValue, screenWidth/2, lidMid);
    endShape();
  
    //lowright
    beginShape();
    vertex(screenWidth/2, screenHeight);
    vertex(screenWidth, screenHeight);
    vertex(screenWidth, lidMid);
    bezierVertex(x+screenWidth/2+eyeSize/4, y+upperValue, x+screenWidth/2-eyeSize/4, y+upperValue, screenWidth/2, lidMid);
    endShape();
    noStroke();
  }
  
  // clean up the bottom bit
  fill(127);
  rect(0, screenHeight, screenWidth, 2*screenHeight);
}
