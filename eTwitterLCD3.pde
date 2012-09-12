#include <Ethernet.h>
#include <SoftwareSerial.h>
#include <string.h>

//Setup Ethernet Link
byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192, 168, 1, 44 };
byte gateway[] = { 192, 168, 1, 254 };   //your router's IP address
byte subnet[] = { 255, 255, 255, 0 };    //subnet mask of the network 
byte server[] = { 128, 121, 146, 100 };  //twitter.com
Client client(server, 80);

//Setup LCD Display
#define txPin 2
#define rxPin 3
#define charDelay 50
SoftwareSerial lcdSerial =  SoftwareSerial(rxPin, txPin);

//Globals
#define cyclePageDelay 8000  //milliseconds between page cycles
#define cycleCount 15        //number of page cycles before contacting server for more data
int readingData = 1;
int readingTag = 0;
int readingText = 0;
int readingSN = 0;
int last_reading_SN = 0;
int readTagNum = 0;
int rxDatalength = 0;
int txDatalength = 0;
int cyclecountnum = 0;
int textLength = 0;

//String arrays
char text[250];
char rxData[250];
char readTag[50];
char last_char;
char textTag[] = "text";
char snTag[] = "screen_name";

void setup()
{
  //Init Serial
  Serial.begin(9600);
  
  //Init Ethernet
  Ethernet.begin(mac, ip, gateway, subnet);
  
  //Init LCD
  pinMode(rxPin, INPUT);
  pinMode(txPin, OUTPUT);
  lcdSerial.begin(9600);
  clearLCD();
  lcdSerial.print("eTwitter Reader v0.3");
  delay(2000);
}

void loop()
{
    Update();
}

void Update(){
  if (client.connect()) {
    Serial.println("connected to server.");
    client.println("GET /statuses/friends_timeline/YOURTWITTERNAME.xml HTTP/1.0");
    client.println("Authorization: Basic AUTH_KEY_GOES_HERE");
    client.println();

    while (client.connected() && readingData)
      readInData();
    
    client.stop();

    appendText();
    updateLCD();
    
    resetVars();
  }
  else {
    Serial.println("connection failure.");
    clearLCD();
    lcdSerial.print("Connection failure. Check network.");
    delay(30000);
  }
}

void readInData(){
  if (client.available()) {
    char c = client.read();
      
    if (last_char == 60 && c != 47) {  // "</" we're reading the beginning of a tag, not the end
      readingTag = 1;
      clearStr(readTag);
      readTagNum = 0;
    }
    else if (c == 62) // ">" detected...tag ended
      readingTag = 0; 
    else if (last_char == 60 && c == 47) // end of the tag - don't allow anymore to be parsed until next tag
      clearStr(readTag);
      
    if (readingTag) {  //we're reading a tag, shove it into this buffer so we can check it out after we've read the whole tag
      readTag[readTagNum++] = c;
    }
    else { //see if the tag we're looking at matches what we need
      if (strcmp(readTag, textTag) == 0 && c != 60 && c != 62)
        readingText = 1;
      else if (strcmp(readTag, snTag) == 0 && c != 60 && c != 62)
        readingSN = 1;
      else  //we're either looking at the wrong tag or there's a greaterthan/lessthan
        readingText = readingSN = 0;
    }
      
    if (readingSN == 0 && last_reading_SN == 1) //state change...once we've read through a tweet we no longer need data
      readingData = 0;

    if (readingText)
      text[textLength++] = c;
    else if (readingSN)
      rxData[rxDatalength++] = c;
        
    last_reading_SN = readingSN;
    last_char = c;
  }
}

void clearLCD(){
   lcdSerial.print(0xFE, BYTE);   //command flag
   lcdSerial.print(0x01, BYTE);   //clear command.
   delay(charDelay);
}

void updateLCD(){
  if (rxDatalength > 80) { //long message - need to cycle the display between 2 pages
    while (cyclecountnum < cycleCount)
    {
      clearLCD();
      while (txDatalength < 80) {
        lcdSerial.print(rxData[txDatalength++]);
        delay(charDelay);
      }
      delay(cyclePageDelay);
      cyclecountnum++;
      clearLCD();
      while (txDatalength < rxDatalength) {
        lcdSerial.print(rxData[txDatalength++]);
        delay(charDelay);
      }
      delay(cyclePageDelay);
      cyclecountnum++;
      txDatalength = 0;
    }
    cyclecountnum = 0;
  }
  else {
    clearLCD();
    while (txDatalength < rxDatalength) {
      lcdSerial.print(rxData[txDatalength++]);
      delay(charDelay);
    }
    while (cyclecountnum < cycleCount) {
      delay(cyclePageDelay);
      cyclecountnum++;
    }
    cyclecountnum = 0;
  }
}

void clearStr (char* str) {
   int len = strlen(str);
   for (int c = 0; c < len; c++) {
      str[c] = 0;
   }
}

void appendText() {
  rxData[rxDatalength++] = 58;  //colon
  rxData[rxDatalength++] = 32;  //space
  //Add the text of the tweet in front of the screen name
  for (int c = 0; c < textLength; c++) {
    rxData[rxDatalength++] = text[c];
  }
}

void resetVars() {
  readingData = 1;
  readingTag = 0;
  readingText = 0;
  readingSN = 0;
  last_reading_SN = 0;
  readTagNum = 0;
  rxDatalength = 0;
  txDatalength = 0;
  cyclecountnum = 0;
  textLength = 0;
  clearStr(rxData);
  clearStr(readTag);
  clearStr(text);
  last_char = 0;
}
