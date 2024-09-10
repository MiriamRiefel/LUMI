/** LUMI eyes control software
 
 Lumi uses two LED matrix eyes of 96 x 80 pixels controlled over HDMI.
 the first 192x80 pixels of a screen are transferred to these Matrices.
 
 Libraries used:
 - GameControlPlus for Processing V3 (c) 2020 Peter Lager
 - Sound (processing standard)
 
 search for 'CHANGE THIS' to find lines of code where you can easily change important constants.
 
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

int imageNumber;
float pupilPosX, pupilPosY, pupilSize;
boolean blink;
boolean dilate;
int emotionalState;

int squareLastUpdateTime = 0;
float leftPupilX = 0;
float leftPupilY = 0;
float leftPupilSize = 0;
float rightPupilX = 0;
float rightPupilY = 0;
float rightPupilSize = 0;

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
float minPupilSize = eyeSize * 0.32f; // CHANGE THIS IF YOU WANT EXTREMER/LESS EXTREME CONTRAST IN PUPIL SIZE (lower is more contrast
float maxPupilSize = eyeSize * 0.7f;  // CHANGE THIS IF YOU WANT EXTREMER/LESS EXTREME CONTRAST IN PUPIL SIZE (higher is more contrast)
float basePupilSize = eyeSize * 0.58f; 
float dilationSpeed = 0.1f; // CHANGE THIS IF YOU WANT THE PUPILS TO DILATE SLOWER/FASTER (higher is faster)
float contractionSpeed = 0.05f; // CHANGE THIS IF YOU WANT THE PUPILS TO CONTRACT SLOWER/FASTER (higher is faster)
int lastEyeMoveTime = 0;
int eyeMoveThreshold = 200; // Time in milliseconds to consider eyes as focused
boolean isFocusing = false;
float focusingProbability = 0.4; // Variable to control the probability of being judged as focusing

//for animation of calculating
int currentRotation = 0;
int lastRotationTime = 0; 
int rotationInterval = 100; // CHANGE THIS IF YOU WANT TO CHANGE THE PACE OF THE ROTATION DOTS AROUND THE PUPILS
//and animation for other decorations
int currentDecoration = 0;
int lastDecorationTime = 0;
int decorationInterval = 500; // CHANGE THIS IF YOU WANT TO CHANGE THE PACE OF SWITCHING EYEBALL DECORATION

// draw an image by filename that can scale (for the pupils)
public void drawImage(String imageName, float scale, float x, float y) {
  PImage img = loadImage(imageName);
  float scaledSize = img.width*scale;
  image(img, x - scaledSize/2, y - scaledSize/2, scaledSize, scaledSize);
}

// draw an image that gets cropped in synchronization with the eye movement (for the eyeball decoration)
public void drawCropImage(String imageName, float x, float y, float xBias, float yBias, int screenWidth, int screenHeight, int xOffset){
  PImage img = loadImage(imageName);
  PImage imgCrop = img.get(int(img.width/2 - x + xBias), int(img.height/2 - y + yBias), screenWidth/2, screenHeight);
  image(imgCrop, xOffset, 0);
}


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
    fill(255, 0, 0, 155); //for the irismasks according to emotions, but more transparant than the original design. 
    emotionalState = 4; //angry
  }
  else if (sndCalculate.isPlaying()) {
    fill(255,255,0,100);
    emotionalState = 3; //calculating
  }
  else if (sndNo.isPlaying()) {
    fill(0,0,255,100);
    emotionalState = 2; //sad eyes
  }
  else if (sndYes.isPlaying()) {
    fill(0,255,0,100);
    emotionalState = 1; //happy eyes
  }
  else if (sndBreakdown.isPlaying()) {
    fill(0,0,0,100);
    emotionalState = 5;
  }
  else {
    fill(0, 255, 100, 0);
    emotionalState = 0; //default=neutral
  }
  noStroke();
  if(mode==0) blink = true;
  //  image(eyeImg, x-144, y-121);
  //  image(eyeImg, x+screenWidth/2-144, y-121);
  
  // raise/lower the height of the eyes slightly when happy/sad, also to fit the lids. 
  int eyeHeight; 
  if (emotionalState == 1) eyeHeight = y-10;
  else if (emotionalState == 2) eyeHeight = y+5;
  else eyeHeight = y;
  
  // now we start drawing the eyes, from back to front. 
  // first the background
  drawCropImage("bg.png", x, eyeHeight, 0, 0, screenWidth, screenHeight, screenWidth/2);
  drawCropImage("bg.png", x, eyeHeight, 0, 0, screenWidth, screenHeight, 0);
  
  //then the iris
  drawImage("eye2a.png", 1, x, eyeHeight);
  drawImage("eye2a.png", 1, x + screenWidth / 2, eyeHeight);
  drawImage("eye2b.png", 1, x, eyeHeight);
  drawImage("eye2b.png", 1, x + screenWidth / 2, eyeHeight); 
  
  //extra colormask over the irises for emotional states
  ellipse(x, eyeHeight, eyeSize, eyeSize);
  ellipse(x+screenWidth/2, eyeHeight, eyeSize, eyeSize);
  
  // now the pupils, they resize according to dilation/contraction (some layers more than others with the pow function)
  float pupilScale = pupilSize / (eyeSize/2); 
  drawImage("eye2c.png", pupilScale, x, eyeHeight);
  drawImage("eye2c.png", pupilScale, x + screenWidth / 2, eyeHeight);
  
  // one layer of the pupils animates during calculation state of the robot, along with extra rotation decoration
  if (emotionalState == 3) {
    blink = false;
    String[] rotatingImgs;
    rotatingImgs = new String[8];
    rotatingImgs[0] = "eye2i.png";
    rotatingImgs[1] = "eye2i-r1.png";
    rotatingImgs[2] = "eye2i-r2.png";
    rotatingImgs[3] = "eye2i-r3.png";
    rotatingImgs[4] = "eye2i-r4.png";
    rotatingImgs[5] = "eye2i-r5.png";
    rotatingImgs[6] = "eye2i-r6.png";
    rotatingImgs[7] = "eye2i-r7.png";
    
    int currentTime = millis();
    if (currentTime - lastRotationTime >= rotationInterval) {
      lastRotationTime = currentTime;
      currentRotation = (currentRotation + 1) % rotatingImgs.length;
      if (currentRotation % 4 == 0) {
        drawImage("eye2d.png", pow(pupilScale, 2), x, eyeHeight);
        drawImage("eye2d.png", pow(pupilScale, 2), x + screenWidth / 2, eyeHeight);
      }
    }
    drawCropImage(rotatingImgs[currentRotation], x, eyeHeight, 0, 0, screenWidth, screenHeight, screenWidth/2);
    drawCropImage(rotatingImgs[currentRotation], x, eyeHeight, 0, 0, screenWidth, screenHeight, 0);
  }
  else {
    gpad.getButton("EYELID").pressed();
    drawImage("eye2d.png", pow(pupilScale, 2), x, eyeHeight);
    drawImage("eye2d.png", pow(pupilScale, 2), x + screenWidth / 2, eyeHeight);
  }
  drawImage("eye2e.png", pupilScale, x, eyeHeight);
  drawImage("eye2e.png", pupilScale, x + screenWidth / 2, eyeHeight);  
  drawImage("eye2f.png", pow(pupilScale, 3), x, eyeHeight);
  drawImage("eye2f.png", pow(pupilScale, 3), x + screenWidth / 2, eyeHeight);  
  
  // and some extra decoration. the robotic beams going from the center change. at any point 2 out of 3 decorations are displayed. 
  int currentTime = millis();
  if (currentTime - lastDecorationTime >= decorationInterval) {
    lastDecorationTime = currentTime;
    currentDecoration = (currentDecoration + 1) % 3;
  }
  if (currentDecoration == 0) {
    drawCropImage("eye2g.png", x, eyeHeight, 0, 1.3, screenWidth, screenHeight, screenWidth/2);
    drawCropImage("eye2g-flip.png", x, eyeHeight, 0, -1.3, screenWidth, screenHeight, 0);
    drawCropImage("eye2h.png", x, eyeHeight, 0, 0, screenWidth, screenHeight, screenWidth/2);
    drawCropImage("eye2h-flip.png", x, eyeHeight, 0, 0, screenWidth, screenHeight, 0);
  } 
  else if (currentDecoration == 1) {
    drawCropImage("eye2h.png", x, eyeHeight, 0, 0, screenWidth, screenHeight, screenWidth/2);
    drawCropImage("eye2h-flip.png", x, eyeHeight, 0, 0, screenWidth, screenHeight, 0);
    drawCropImage("eye2j.png", x, eyeHeight, 0, 0, screenWidth, screenHeight, screenWidth/2);
    drawCropImage("eye2j-flip.png", x, eyeHeight, 0, 0, screenWidth, screenHeight, 0);
  } 
  else if (currentDecoration == 2) {
    drawCropImage("eye2j.png", x, eyeHeight, 0, 0, screenWidth, screenHeight, screenWidth/2);
    drawCropImage("eye2j-flip.png", x, eyeHeight, 0, 0, screenWidth, screenHeight, 0);
    drawCropImage("eye2g.png", x, eyeHeight, 0, 1.3, screenWidth, screenHeight, screenWidth/2);
    drawCropImage("eye2g-flip.png", x, eyeHeight, 0, -1.3, screenWidth, screenHeight, 0);
  } 
  // here the pink eyeball stains are drawn
  drawCropImage("eye2k.png", x, eyeHeight, 0, 0, screenWidth, screenHeight, screenWidth/2);
  drawCropImage("eye2k-flip.png", x, eyeHeight, 0, 0, screenWidth, screenHeight, 0);
  
  fill(0); // black for the eyelids

  if (blink == true) dLid = -eyeSize/10;
  else dLid = eyeSize/10;
  upperValue += dLid;
  if (upperValue>eyeSize/2) upperValue = eyeSize/2;
  if (upperValue<0) upperValue = 0;
  
  
  // finally the drawing of the eyelids according to the emotional state!
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
