---------------------------------------------------------------------------------
-- Author: Yuanbo Peng <bobpeng.bham.uk@gmail.com>
-- Create Date: 21.2.2019
-- Project Name: Combination Lock
-- Target Devices: XILINX NEXYS 4 DDR
-- Tool Versions: Vivado
-- Description: Keys: 4, 2, 7, 5, 7
-- Revision: 1.0
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
ENTITY lock IS
	PORT
	(
		BTNU, BTNL, BTNR : IN std_logic;
		SEGMENTS         : OUT std_logic_vector(6 DOWNTO 0);
		DIGITS           : OUT std_logic_vector(7 DOWNTO 0);
		SWITCHES         : IN std_logic_vector(3 DOWNTO 0);
		LEDS             : OUT std_logic_vector(15 DOWNTO 0);
		CLK100MHZ        : IN std_logic
	);
END lock;
ARCHITECTURE Behavioral OF lock IS
	----- All States -----
	TYPE states IS (INI, A, B, C, D, E, RES, INI_R, A_R, B_R, RES_R);
	SIGNAL state : states;
	----- Slow Clock -----
	TYPE deb_states IS (DEB_INI, SHIFT_STATE);
	SIGNAL clk_slow    : std_logic;
	SIGNAL deb_state   : deb_states;
	SIGNAL deb_signal  : std_logic;
	SIGNAL count_slow  : INTEGER   := 0;
	SIGNAL count_shift : INTEGER   := 0;
	----- Flicker -----
	SIGNAL count_flk   : INTEGER   := 0;
	SIGNAL switch_flk  : std_logic := '0';
	----- Multi-Display Counter -----
	SIGNAL count_disp  : std_logic_vector(15 DOWNTO 0);
	----- User Inputs Array -----
	SIGNAL usr_in      : std_logic_vector(19 DOWNTO 0);
	----- Correct Code -----
	SIGNAL keys        : std_logic_vector(19 DOWNTO 0) := "01000010011101010111";
	----- Code Sequence Array -----
	TYPE code_tab IS ARRAY (0 TO 1) OF INTEGER RANGE 1 TO 5;
	----- Random Code Sequence Array -----
	TYPE code_rand IS ARRAY (19 DOWNTO 0) OF code_tab;
	SIGNAL code_rand_array : code_rand;
	----- Random Number Counter -----
	SIGNAL rand_stop       : std_logic             := '0';
	SIGNAL rand_index      : INTEGER RANGE 0 TO 19 := 0;
	SIGNAL rand_1, rand_2  : INTEGER RANGE 1 TO 5;
	SIGNAL anw, usr        : std_logic_vector(7 DOWNTO 0);
	----- Functions -----
	FUNCTION bits_4_to_segment (
		usr_input : std_logic_vector(3 DOWNTO 0))
		RETURN std_logic_vector IS
		VARIABLE segment : std_logic_vector(6 DOWNTO 0);
	BEGIN
		CASE(usr_input) IS
			WHEN "0000"  => segment  := "1000000"; -- 0
			WHEN "0001"  => segment  := "1111001"; -- 1
			WHEN "0010"  => segment  := "0100100"; -- 2
			WHEN "0011"  => segment  := "0110000"; -- 3
			WHEN "0100"  => segment  := "0011001"; -- 4
			WHEN "0101" => segment := "0010010"; -- 5
			WHEN "0110" => segment := "0000010"; -- 6
			WHEN "0111" => segment := "1111000"; -- 7
			WHEN "1000" => segment := "0000000"; -- 8
			WHEN "1001" => segment := "0010000"; -- 9
			WHEN OTHERS     => segment     := "1000000"; -- 0
		END CASE;
		RETURN segment;
	END;
	FUNCTION bits_3_to_digits (
		count_disp : std_logic_vector(2 DOWNTO 0))
		RETURN std_logic_vector IS
		VARIABLE dig : std_logic_vector(7 DOWNTO 0);
	BEGIN
		CASE(count_disp) IS
			WHEN "000" => dig := "01111111";
			WHEN "001" => dig := "10111111";
			WHEN "010" => dig := "11011111";
			WHEN "011" => dig := "11101111";
			WHEN "100" => dig := "11110111";
			WHEN "101" => dig := "11111011";
			WHEN "110" => dig := "11111101";
			WHEN "111" => dig := "11111110";
		END CASE;
		RETURN dig;
	END;
	FUNCTION int_to_segment (
		rand_num : INTEGER RANGE 1 TO 5)
		RETURN std_logic_vector IS
		VARIABLE segment : std_logic_vector(6 DOWNTO 0);
	BEGIN
		CASE(rand_num) IS
			WHEN 5      => segment      := "0010010";
			WHEN 4      => segment      := "0011001";
			WHEN 3      => segment      := "0110000";
			WHEN 2      => segment      := "0100100";
			WHEN 1      => segment      := "1111001";
			WHEN OTHERS => segment := "1111111";
		END CASE;
		RETURN segment;
	END;
	----- Functions End -----
BEGIN
	----- All random code sequence array initialization -----
	code_rand_array <= ((3, 5), (5, 2), (4, 5), (1, 5), (2, 4),
		(2, 3), (1, 4), (3, 4), (3, 1), (1, 3),
		(1, 2), (4, 3), (5, 1), (5, 3), (5, 4),
		(4, 1), (4, 2), (3, 2), (2, 5), (2, 1));
	----- Generate deceleration clock -----
	PROCESS (CLK100MHZ) BEGIN
		IF rising_edge(CLK100MHZ) THEN
			IF count_slow = 1500000 THEN
				clk_slow   <= '1';
				count_slow <= 0;
			ELSE
				clk_slow   <= '0';
				count_slow <= count_slow + 1;
			END IF;
		END IF;
	END PROCESS;
	----- Main state transition process -----
	PROCESS (clk_slow, BTNU, BTNR)
	BEGIN
		IF rising_edge(clk_slow) THEN
			------ Debounce Button BTNL ------
			CASE(deb_state) IS
				WHEN DEB_INI =>
				IF (BTNL = '1') THEN
					deb_state <= SHIFT_STATE;
				ELSE
					deb_state <= DEB_INI;
				END IF;
				deb_signal <= '0';
				WHEN SHIFT_STATE =>
				IF (count_shift = 8) THEN
					count_shift <= 0;
					IF (BTNL = '1') THEN
						deb_signal <= '1';
					END IF;
					deb_state <= DEB_INI;
				ELSE
					count_shift <= count_shift + 1;
				END IF;
			END CASE;
			----- BTNU resets all states to INI of Part 1 & 2 -----
			IF BTNU = '1' THEN
				usr_in(19 DOWNTO 0) <= (OTHERS => '0');
				state               <= INI;
				----- BTNR resets all states and signal of Part 3 -----
			ELSIF BTNR = '1' THEN
				anw       <= "00000000";
				usr       <= "00000000";
				rand_stop <= '1';
				rand_1    <= code_rand_array(rand_index)(0);
				rand_2    <= code_rand_array(rand_index)(1);
				state     <= A_R;
				----- Read operation based on debounced signal -----
			ELSIF (deb_signal = '1') THEN
				CASE(state) IS
					--- Part 1 & 2 ---
					WHEN INI =>
					usr_in(19 DOWNTO 16) <= SWITCHES(3 DOWNTO 0);
					state                <= A;
					WHEN A =>
					usr_in(15 DOWNTO 12) <= SWITCHES(3 DOWNTO 0);
					state                <= B;
					WHEN B =>
					usr_in(11 DOWNTO 8) <= SWITCHES(3 DOWNTO 0);
					state               <= C;
					WHEN C =>
					usr_in(7 DOWNTO 4) <= SWITCHES(3 DOWNTO 0);
					state              <= D;
					WHEN D =>
					usr_in(3 DOWNTO 0)  <= SWITCHES(3 DOWNTO 0);
					state               <= E;
					WHEN E     => state <= E;
					WHEN RES   => state <= RES;
					--- Part 3 ---
					WHEN INI_R => state <= INI_R;
					WHEN A_R   =>
					-------------------------------
					--- Generate an array of correct
					--- sequences corresponding to random numbers
					-------------------------------
					CASE(rand_1) IS
						WHEN 1      => anw(7 DOWNTO 4) <= "0100";
						WHEN 2      => anw(7 DOWNTO 4) <= "0010";
						WHEN 3      => anw(7 DOWNTO 4) <= "0111";
						WHEN 4      => anw(7 DOWNTO 4) <= "0101";
						WHEN 5      => anw(7 DOWNTO 4) <= "0111";
						WHEN OTHERS => anw(7 DOWNTO 4) <= "0000";
					END CASE;
					--- Read the user input in usr array ---
					usr(7 DOWNTO 4) <= SWITCHES(3 DOWNTO 0);
					CASE(rand_2) IS
						WHEN 1      => anw(3 DOWNTO 0) <= "0100";
						WHEN 2      => anw(3 DOWNTO 0) <= "0010";
						WHEN 3      => anw(3 DOWNTO 0) <= "0111";
						WHEN 4      => anw(3 DOWNTO 0) <= "0101";
						WHEN 5      => anw(3 DOWNTO 0) <= "0111";
						WHEN OTHERS => anw(3 DOWNTO 0) <= "0000";
					END CASE;
					state <= B_R;
					WHEN B_R =>
					usr(3 DOWNTO 0) <= SWITCHES(3 DOWNTO 0);
					state           <= RES_R;
					WHEN RES_R =>
					state <= RES_R;
				END CASE;
			END IF;
			IF state = RES_R THEN
				rand_stop <= '0';
			END IF;
			----- Generate a random number array index -----
			IF rand_stop = '0' THEN
				IF rand_index = 19 THEN
					rand_index <= 1;
				ELSE
					rand_index <= rand_index + 1;
				END IF;
			END IF;
			----- Flicker Digits Digits -----
			IF (count_flk = 50) THEN
				count_flk  <= 0;
				switch_flk <= NOT switch_flk;
			ELSE
				count_flk <= count_flk + 1;
			END IF;
			IF state = E THEN
				IF switch_flk = '1' THEN
					state <= RES;
				END IF;
			ELSIF state = RES THEN
				IF switch_flk = '0' THEN
					state <= E;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	-------------------------------
	-- Display counter for multi-digital display at the same time.
	-------------------------------
	PROCESS (CLK100MHZ)
	BEGIN
		IF rising_edge (CLK100MHZ) THEN
			count_disp <= count_disp + 1;
			IF count_disp = "1110001101010000" THEN
				count_disp <= (OTHERS => '0');
			END IF;
		END IF;
	END PROCESS;
	--------------------------------
	-- Output Process
	--------------------------------
	Output : PROCESS (state)
		VARIABLE seg : std_logic_vector(6 DOWNTO 0);
		VARIABLE dig : std_logic_vector(7 DOWNTO 0);
	BEGIN
		------------------------
		-- Display different content according to different status
		------------------------
		CASE (state) IS
				--- Part 3 Display ---
			WHEN INI_R =>
				dig := "11111111";
				seg := "1111111";
				LEDS <= "0000000000000000";
			WHEN A_R =>
				dig := "01111111";
				seg := int_to_segment(rand_1);
				LEDS <= "0000000000000000";
			WHEN B_R =>
				dig := "10111111";
				seg := int_to_segment(rand_2);
			WHEN RES_R =>
				-----------------------
				--- Determine the user input and the correct
				--- sequence are consistent or not
				-------------
				IF anw(7 DOWNTO 0) = usr(7 DOWNTO 0) THEN
					LEDS <= "1111111111111111";
					CASE(count_disp(15 DOWNTO 14)) IS
					WHEN "00" => dig := "11111101";
					WHEN "01" => dig := "11111110";
					WHEN OTHERS     => dig     := "11111111";
					END CASE;
					CASE(count_disp(15 DOWNTO 14)) IS
					WHEN "00" => seg := "1000000";
					WHEN "01" => seg := "0001001";
					WHEN OTHERS     => seg     := "1111111";
					END CASE;
				ELSE
					CASE(count_disp(15 DOWNTO 14)) IS
					WHEN "00" => dig := "11111110";
					WHEN "01" => dig := "11111101";
					WHEN "10" => dig := "11111011";
					WHEN OTHERS     => dig     := "11111111";
					END CASE;
					CASE(count_disp(15 DOWNTO 14)) IS
					WHEN "00" => seg := "0101111";
					WHEN "01" => seg := "0101111";
					WHEN "10" => seg := "0000110";
					WHEN OTHERS     => seg     := "1111111";
					END CASE;
				END IF;
				--- Part 2 Display ---
			WHEN INI =>
				dig := "11111111";
				seg := "1111111";
				LEDS <= "0000000000000000";
			WHEN A =>
				dig := "01111111";
				seg := bits_4_to_segment(usr_in(19 DOWNTO 16));
			WHEN B =>
				CASE(count_disp(15 DOWNTO 14)) IS
				WHEN "00" => dig := "01111111";
				WHEN "01" => dig := "10111111";
				WHEN OTHERS     => dig     := "11111111";
				END CASE;
				CASE(count_disp(15 DOWNTO 14)) IS
				WHEN "00"  => seg  := bits_4_to_segment(usr_in(19 DOWNTO 16));
				WHEN "01" => seg := bits_4_to_segment(usr_in(15 DOWNTO 12));
				WHEN OTHERS      => seg      := "1111111";
				END CASE;
			WHEN C =>
				CASE(count_disp(15 DOWNTO 14)) IS
				WHEN "00" => dig := "01111111";
				WHEN "01" => dig := "10111111";
				WHEN "10" => dig := "11011111";
				WHEN OTHERS      => dig      := "11111111";
				END CASE;
				CASE(count_disp(15 DOWNTO 14)) IS
				WHEN "00" => seg := bits_4_to_segment(usr_in(19 DOWNTO 16));
				WHEN "01" => seg := bits_4_to_segment(usr_in(15 DOWNTO 12));
				WHEN "10" => seg := bits_4_to_segment(usr_in(11 DOWNTO 8));
				WHEN OTHERS      => seg      := "1111111";
				END CASE;
			WHEN D =>
				CASE(count_disp(15 DOWNTO 14)) IS
				WHEN "00" => dig := "01111111";
				WHEN "01" => dig := "10111111";
				WHEN "10" => dig := "11011111";
				WHEN "11" => dig := "11101111";
				WHEN OTHERS      => dig      := "11111111";
				END CASE;
				CASE(count_disp(15 DOWNTO 14)) IS
				WHEN "00" => seg := bits_4_to_segment(usr_in(19 DOWNTO 16));
				WHEN "01" => seg := bits_4_to_segment(usr_in(15 DOWNTO 12));
				WHEN "10" => seg := bits_4_to_segment(usr_in(11 DOWNTO 8));
				WHEN "11" => seg := bits_4_to_segment(usr_in(7 DOWNTO 4));
				WHEN OTHERS      => seg      := "1111111";
				END CASE;
			WHEN E =>
				dig := bits_3_to_digits(count_disp(15 DOWNTO 13));
				CASE(count_disp(15 DOWNTO 13)) IS
				WHEN "000" => seg := bits_4_to_segment(usr_in(19 DOWNTO 16));
				WHEN "001" => seg := bits_4_to_segment(usr_in(15 DOWNTO 12));
				WHEN "010" => seg := bits_4_to_segment(usr_in(11 DOWNTO 8));
				WHEN "011" => seg := bits_4_to_segment(usr_in(7 DOWNTO 4));
				WHEN "100" => seg := bits_4_to_segment(usr_in(3 DOWNTO 0));
				WHEN "101" => seg := "1111111";
				WHEN "110" => seg := "1111111";
				WHEN "111" => seg := "1111111";
				WHEN OTHERS      => seg      := "1111111";
				END CASE;
			WHEN RES =>
				IF (state = RES) AND (usr_in = keys) THEN
					LEDS <= "1111111111111111";
					CASE(count_disp(15 DOWNTO 14)) IS
					WHEN "00" => dig := "11111101";
					WHEN "01" => dig := "11111110";
					WHEN OTHERS      => dig      := "11111111";
					END CASE;
					CASE(count_disp(15 DOWNTO 14)) IS
					WHEN "00" => seg := "1000000";
					WHEN "01" => seg := "0001001";
					WHEN OTHERS      => seg      := "1111111";
					END CASE;
				ELSE
					CASE(count_disp(15 DOWNTO 14)) IS
					WHEN "00" => dig := "11111110";
					WHEN "01" => dig := "11111101";
					WHEN "10" => dig := "11111011";
					WHEN OTHERS      => dig      := "11111111";
					END CASE;
					CASE(count_disp(15 DOWNTO 14)) IS
					WHEN "00" => seg := "0101111";
					WHEN "01" => seg := "0101111";
					WHEN "10" => seg := "0000110";
					WHEN OTHERS      => seg      := "1111111";
					END CASE;
				END IF;
		END CASE;
		------------
		--- The final result of the processed
		--- display result
		------------
		SEGMENTS <= seg;
		DIGITS   <= dig;
	END PROCESS Output;
END Behavioral;