--Simon Scott, 2011

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library UNISIM; --included because Xilinx Primitives are used
use UNISIM.VComponents.all;

entity blinky is
	Port (
		SYS_CLK_N 	: in STD_LOGIC; --System Clock Negative input port
		SYS_CLK_P	: in STD_LOGIC; --System Clock Positive input port
		USER_LED 	: out STD_LOGIC_VECTOR(7 downto 0) --Output byte representing the 8 LEDs
	);
end blinky;
architecture Behavioral of blinky is



--Declare signals
signal SYS_CLK_BUF	: STD_LOGIC;
signal SYS_CLK_SLOW	: STD_LOGIC;
signal SYS_CLK_FB	: STD_LOGIC;



begin
	--BUFG for SYS_CLOCK, the differential buffer for the System Clock
	IBUFGDS_SYS_CLK: IBUFGDS
	generic map

	(
		DIFF_TERM => TRUE, 		-- Differential Termination
		IBUF_LOW_PWR => FALSE, 	-- Low power (TRUE) vs. performance (FALSE)
		IOSTANDARD => "LVDS_25"
	)

	port map
	(
		I 	=> 	SYS_CLK_P,
		IB => 	SYS_CLK_N,
		O 	=>  	SYS_CLK_BUF
	);

        --PLL_BASE, the phase-lock loop
	PLL_SYS_CLK : PLL_BASE 
   generic map 
   (
		BANDWIDTH          => "OPTIMIZED",
		CLKIN_PERIOD       => 10.0,
		CLKOUT0_DIVIDE     => 1,
		CLKOUT1_DIVIDE     => 1,
		CLKOUT2_DIVIDE     => 1,
		CLKOUT3_DIVIDE     => 1,
		CLKOUT4_DIVIDE     => 1,
		CLKOUT5_DIVIDE     => 1,
		CLKOUT0_PHASE      => 0.000,
		CLKOUT1_PHASE      => 0.000,
		CLKOUT2_PHASE      => 0.000,
		CLKOUT3_PHASE      => 0.000,
		CLKOUT4_PHASE      => 0.000,
		CLKOUT5_PHASE      => 0.000,
		CLKOUT0_DUTY_CYCLE => 0.500,
		CLKOUT1_DUTY_CYCLE => 0.500,
		CLKOUT2_DUTY_CYCLE => 0.500,
		CLKOUT3_DUTY_CYCLE => 0.500,
		CLKOUT4_DUTY_CYCLE => 0.500,
		CLKOUT5_DUTY_CYCLE => 0.500,
		COMPENSATION       => "INTERNAL",
		DIVCLK_DIVIDE      => 1, --Defined clock division
		CLKFBOUT_MULT      => 4,
		CLKFBOUT_PHASE     => 0.0,
		REF_JITTER         => 0.1
	)
	port map
   (
		CLKFBIN          	=> SYS_CLK_FB,
		CLKIN      		=> SYS_CLK_BUF,
		RST              	=> '0',
		CLKFBOUT         	=> SYS_CLK_FB,
		CLKOUT0          	=> SYS_CLK_SLOW, --The output used 
		CLKOUT1          	=> open,
		CLKOUT2          	=> open,
		CLKOUT3          	=> open,
		CLKOUT4          	=> open,
		CLKOUT5          	=> open,
		LOCKED           	=> open
	);

--Run each time clock changes state

	DATAPATH: process(SYS_CLK_SLOW) --defining the LED behaviour as a stand alone process

	variable led_status1 : STD_LOGIC_VECTOR (7 downto 0) := "00000001"; --various variables used during the behaviour

	variable led_status2 : STD_LOGIC_VECTOR (7 downto 0) := "10000000";

	variable shift_dir : integer range 0 to 15 := 0;

	variable count : integer := 0;

	begin

		if SYS_CLK_SLOW'event and SYS_CLK_SLOW = '1' then --each clock edge
		
			count := count + 1; --a simple counter is used to sub-divide the clock, so the change in the LEDs is visible to the naked eye.

			if count > 400000000 then

				--Shift LEDs

				USER_LED <= led_status1 or led_status2;

				if shift_dir = 0 then

					--Shift left

					led_status1 := STD_LOGIC_VECTOR(signed(led_status1) sll 1); -- conversion to a STD_LOGIC_VECTOR is used to take advantage of the shifts

					led_status2 := STD_LOGIC_VECTOR(signed(led_status2) srl 1); 

				else

					--Shift right

					led_status1 := STD_LOGIC_VECTOR(signed(led_status1) srl 1); 

					led_status2 := STD_LOGIC_VECTOR(signed(led_status2) sll 1); 

				end if;

				--Reverse direction if necessary

				if led_status1 = "10000000" then

					shift_dir := 1;

				elsif led_status1 = "00000001" then

					shift_dir := 0;

				end if;

				count := 0;

			end if;

		end if;

	end process;

end Behavioral;
