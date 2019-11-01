# Digital Design - Combination Lock

- Author: Yuanbo Peng \<bobpeng.bham.uk@gmail.com\>
- Create Date: 21.2.2019
- Project Name: Combination Lock
- Target Devices: XILINX NEXYS 4 DDR
- Tool Versions: Vivado
- Keys: 4, 2, 7, 5, 7
- Revision: 1.0

## Introduction

This project contains a combination lock from logic design to construction at the hardware level. And the entire process of improving the security of this lock to anti-spyware scanning and deciphering.
The aim of this project is to implement the above combination lock on the FPGA board using VHDL language and finite state machine technology. On the interactive side, the input and display will use the push buttons, slider switches, LEDs and 7-segment display of the FPGA board.

There are some possible solutions provided to address the problems, such as debounce, random number generation and combination check, and selects the appropriate strategy at different stages.

## 1. Overview

In this project, the Nexys 4 DDR starter board produced by Digilent will be used. This board makes use of the Artix 7 XC7A100T FPGA from Xilinx. The following diagram shows the starter board:

<center>

<img src="http://gogo-static.yunxiangshijue.com/Nexys%204%20DDR%20FPGA%20Board.png" width="50%">

</center>

## 2. A Simple Digital Combination Lock

In this part of the design, the user will be asked to enter a 5-digit code sequence. If the sequence is correct, all LEDs on the FPGA board will be illuminated. All the following experiments will use 4,2,7,5,7 as the code sequence.

The user interface will operate as follows:

- The *BTNU* button will indicate that the user can start entering their own password sequence.

- Each digit will be entered as a binary form via slider switches.

- Once the user has prepared the inputs of slider switches, the user could press the *BTNL* button to read in the number and enter the next digit until the 5-digit password sequence is entered.
  
- If the code sequence is correct, then the LEDs will be lighted up.

## 2.1 The Finite State Machine Diagram


<center>

<img src="http://gogo-static.yunxiangshijue.com/FSMD.png" width="70%">

</center>

The initialization status is *INI*. When the *BTNU* button is pressed, all states will go to the *INI* state. In the *INI* state, all the array of user input *usr_in* will be zeroed. States A, B, C, D, E, RES Each state starts to next when *BTNL* is pressed. If there is no input signal, the states remain unchanged.

## 2.2 Debounce Algorithm

Because the buttons are mostly mechanical switches, the signal instability will occur at the connection point when the switch is switched. It can be seen from the above figure: Although the button is pressed only once, the actual generated button signal is not only once. If a high- speed clock frequency is used for sampling, such as 100MHz, it will cause a wrong judgment. The system mistakenly believes that the user has made multiple pushes.

<center>

<img src="http://gogo-static.yunxiangshijue.com/Debounce%20Algorithm.png" width="70%">

</center>

Therefore, the key steps in this project to solve the problem are the following:

- Down-clock processing of high-speed clock signals, extending the sampling period to ensure sample authenticity as much as possible

- Based on the clock signal after frequency reduction, the button signal is delayed
sampled, and when the sampling button signal is at a high level (pressed) at a fixed time interval, a debounce button signal is output.


## 2.3 Code Sequence 

The idea at this stage is to load a right code sequence array *'keys'* at system initialization and a user input array *'usr_in'*. When the user presses the button *BTNL* once to perform the reading and state switching, the corresponding digit of the *usr_in* array is updated. After all the five digits are inputted, it is determined whether the *usr_in* array and the keys array are identical, and the corresponding result will be displayed.


## 3. Improving the User Interface

The main purpose of this part of the design is to enhance the user experience, digits and 7-segment display will be used to display the five digits and judgment information entered by the user.

- When the button *BTNL* is pressed, the entered numbers are displayed in real time one the digital display tube in sequence.

- After five numbers are entered, the system will display the correct information *‘OK’* and the error message *‘Err’* on the digital display tube according to the correctness of the code sequence.

- The display of *‘OK’* and *‘Err’* will be alternate at one second intervals with display of the number entered.
<center>

<img src="http://gogo-static.yunxiangshijue.com/ERR.png" width="50%">

</center>
<center>

<img src="http://gogo-static.yunxiangshijue.com/OK.png" width="50%">

</center>

## 3.1 Multi-digits Display

The digits display will be improved by using a counter to switches rapidly between the different digits. The display unit will then step through each digit at a time (by causing digit to go cyclically through the sequence 1110111, 1111011, 1111101, 1111110) and outputs the required values for that segment on segments. Although only one digit at a time is driven, the persistence of the LED and the insensitivity of human’s eyes to durations means that the display will look as if all digits are being addressed at the same time.

This is achieved by having a 100 MHz counter that will count to 58192 (binary 1110001101010000) then reset itself to zero and start all over again.

Since there are at most five numbers to be displayed at the same time in this system, it needs to be represented by three-digit binary, so the first three digits of the counter must be changed from 0 to 1 (000 to 111).


## 3.2 Alternately Display

The discontinuous display function is implemented in this design with counters *count_flk* and flag *switch_flk*. To improve code reusability, this counter can be calculated on a slow clock basis. In addition, the flashing speed can be adjusted according to change the count maximum, which is the multiple of slow clock.
The switch flag switch_flk is used as the signal for status switching. If the status is *E*, then when *switch_flk* is 1, the status automatically switches to RES. If the state is at RES, then when *switch_flk* is 0, the state automatically switches to E to achieve the effect of the flashing digital tube.


## 4. An Improved Combination Lock

There is a problem with passwords is spy software that logs user’s keyboard activity could be installed secretly onto user’s computer to intercept password. Highly secure systems try to deal with this problem by never asking the user to enter the whole password in a single login.

So that this stage of design to ask users to enter the different random number of their password, for example, for the user the 5th and 1st letter in the password. Then the next time the user logs in, a different pair of letters will be requested.

- A third push button *BTNR* will be used to indicate that the user starts to enter two numbers from the code sequence.

- The system will choose a random number in the range 1 to 5 and display it on the 7-segment display. The user enters the corresponding number from the code sequence using the slider switches and the second push button as normal.

- The system will then choose a different random number in the range 1 to 5 and display it on the 7-segment display. The user enters the corresponding number from the code sequence.
  
- If the two digits are correct, then the system prompts with ‘OK’. Otherwise it gives the message ‘Err’.


## 4.1 The Finite State Machine Diagram

The initialization status is *INI_R*. When the *BTNR* button is pressed, all states will go to the *INI_R* state. In this state, the index random number counter will be stopped, and then two different random numbers *rand_1*, *rand_2* will be generated. In addition, the correct code sequence anw corresponding to the random number and the code sequence user entered usr will be zeroed, and then turned to the state *A_R*. At the same time, the first random number *rand_1* will be displayed on the digital tube and wait for the user to input the corresponding password.

<center>

<img src="http://gogo-static.yunxiangshijue.com/The%20Diagram%20of%20Improved%20User%20Interface%20Lock.png" width="70%">

</center>

The status *B_R* displays the second random number on the digital tube and waits for the user to enter the corresponding password. After the user has entered all two digits, the status will go to *RES_R*, the user input usr and the correct password anw will be compared and the result will be displayed.

## 4.2 Generation of Two Different Random Numbers

The implementation of the random number function can rely on index counters and multidimensional arrays. Because the range of code sequences is 1-5 bits, there are 20 combinations of different two-digit numbers. These combinations can be loaded into a multi-dimensional array with indexes from 0 to 19. When the *BTNU* button is pressed, the counter will stop counting and generate a random number from 0 to 19. This random number can be used as an index to the multi-latitude array to indirectly generate two different 1 to 5 random numbers.

## 4.3 Random Code Sequence Check

The two array containers will be initialized during the initialization phase, *anw* and *usr*. When the *BTNR* button is pressed, two different random numbers are generated, which means that the code corresponding to each random number has also been determined. At this time, the code corresponding to each random number is loaded into the corresponding position of the anw array. When *BTNL* is pressed to read in the user input, each press will update the user input into the usr array. When the two digits are entered, the usr and *anw* arrays will be compared and the corresponding information will be displayed.