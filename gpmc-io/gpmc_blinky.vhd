--Alan Langman, 2011
--modified by Gordon Inggs, 2015

--https://github.com/brandonhamilton/rhino/tree/master/examples/gpmc_test

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;  -- not a standard library

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;


------------------------------------------------------------------------------------
-- Declare input and output pins for gpmc_blinky
------------------------------------------------------------------------------------

entity gpmc_blinky is
port
(
    -- FPGA-processor interface pins
   gpmc_a           : in std_logic_vector(10 downto 1);
   gpmc_d           : inout std_logic_vector(15 downto 0);
   gpmc_clk_i       : in std_logic;
   gpmc_n_cs        : in std_logic_vector(6 downto 0);
   gpmc_n_we        : in std_logic;
   gpmc_n_oe        : in std_logic;
   gpmc_n_adv_ale   : in std_logic;
   gpmc_n_wp        : in std_logic;
   gpmc_busy_0      : out std_logic;
   gpmc_busy_1      : out std_logic;
	 
    -- LED and CLOCK pins
   led              : out std_logic_vector(7 downto 0);
   sys_clk_P		  : in std_logic;
   sys_clk_N	 	  : in std_logic
);
end gpmc_blinky;

------------------------------------------------------------------------------------
-- Architecture of rhino_proc_intrfc_top
------------------------------------------------------------------------------------

architecture rtl of gpmc_blinky is

------------------------------------------------------------------------------------
-- Declare types
------------------------------------------------------------------------------------

	type ram_type is array (63 downto 0) of std_logic_vector(15 downto 0);
	type word32_type is array (1 downto 0) of std_logic_vector(15 downto 0);
	type word64_type is array (3 downto 0) of std_logic_vector(15 downto 0);

------------------------------------------------------------------------------------
-- Declare signals
------------------------------------------------------------------------------------

-- Define signals for the gpmc bus
	signal gpmc_clk_i_b       : std_logic;  --buffered  gpmc_clk_i
    	signal gpmc_address       : std_logic_vector(25 downto 0):=(others => '0');         -- Full de-multiplexed address bus (ref. 16 bits)
    	signal gpmc_data_o        : std_logic_vector(15 downto 0):="0000000000000000";      -- Register for output bus value
    	signal gpmc_data_i        : std_logic_vector(15 downto 0):="0000000000000000";      -- Register for input bus value


--Other signals
	signal heartbeat	: std_logic;
    	signal dcm_locked	: std_logic;
    	signal rd_cs_en  	: std_logic:='0';
    	signal we_cs_en		: std_logic:='0';
	 
--Clocks
	signal sys_clk_100MHz	: std_logic;

-- Debug signals
    	constant VERSION : std_logic_vector(7 downto 0) := "00000001"; --0x01 (1)
   	constant ID      : std_logic_vector(7 downto 0) := "01010001"; --0x51 (81)
    	signal reg_bank: ram_type;
    	signal led_reg : std_logic_vector(15 downto 0) := "1010101001010101";
	signal word32_reg: word32_type := ("0101010101010101","0101010101010101");
  
-- ALIASES
    -- Support 64 memory banks, each with a maximum of 2MW 
	ALIAS reg_bank_address: std_logic_vector(3 downto 0) IS gpmc_address(25 downto 22);  
	-- Currently each register is 64 x 16 
	ALIAS reg_file_address:   std_logic_vector(5 downto 0) IS gpmc_address(5 downto 0);

--==========================
begin --architecture RTL
--==========================

------------------------------------------------------------------------------------
-- Instantiate input buffer for FPGA_PROC_BUS_CLK
------------------------------------------------------------------------------------

IBUFG_gpmc_clk_i : IBUFG
generic map
(
    IBUF_LOW_PWR => FALSE,
    IOSTANDARD => "DEFAULT"
)
port map
(
    I => gpmc_clk_i,
    O => gpmc_clk_i_b
);


------------------------------------------------------------------------------------
-- Instantiate differential input clockl buffer, for 100MHz clock (for UART)
-----------------------------------------------------------------------------------

IBUFGDS_sys_clk: IBUFGDS
generic map
(
	IOSTANDARD => "LVDS_25",
	DIFF_TERM => TRUE,
	IBUF_LOW_PWR => FALSE
)
port map
(
	I => sys_clk_P,
	IB => sys_clk_N,
	O => sys_clk_100MHz
);

------------------------------------------------------------------------------------
-- Misc signal wiring
------------------------------------------------------------------------------------

-- Map important processor bus pins to GPIO header
led <= led_reg(7 downto 0);

-- Set other outputs low
gpmc_busy_0 <= '0';
gpmc_busy_1 <= '0';

-----------------------------------------------------------------------------------
-- Register File: Read
------------------------------------------------------------------------------------

process (gpmc_clk_i_b,gpmc_n_cs,gpmc_n_oe,gpmc_n_we,gpmc_n_adv_ale,gpmc_d,gpmc_a)
begin
  if (gpmc_n_cs /= "1111111")  then             -- CS 1
    if gpmc_clk_i_b'event and gpmc_clk_i_b = '1' then  
		--First cycle of the bus transaction record the address
	if (gpmc_n_adv_ale = '0') then
          gpmc_address <= gpmc_a & gpmc_d;   -- Address of 16 bit word	

	--Second cycle of the bus is read or write
	--Check for read
        elsif (gpmc_n_oe = '0') then
		 	case conv_integer(reg_bank_address) is
			     	when 0 => gpmc_data_o <= ID & VERSION;
			     	when 2 => gpmc_data_o <= word32_reg(conv_integer(reg_file_address));
				when 3 => gpmc_data_o <= reg_bank(conv_integer(reg_file_address));
				when others => gpmc_data_o <= (others => '0');
		   end case;
        --Check for write
	elsif (gpmc_n_we = '0') then
		  case conv_integer(reg_bank_address) is
			  	when 1 => led_reg <= gpmc_data_i;
				when 2 => word32_reg(conv_integer(reg_file_address)) <= gpmc_data_i;
				when 3 => reg_bank(conv_integer(reg_file_address)) <= gpmc_data_i;
			     	when others => null;
			end case;
		end if;
     end if; 
   end if; 
end process;

------------------------------------------------------------------------------------
-- Manage the tri-state bus 
---------------------------------------------------------------------------------
gpmc_d <= gpmc_data_o when (gpmc_n_oe = '0') else (others => 'Z');
gpmc_data_i <= gpmc_d;

end rtl;
