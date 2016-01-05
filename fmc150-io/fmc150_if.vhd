
----------------------------------------------------------------------------
-- Title      : Interfacing RHINO with 4DSP-FMC150
----------------------------------------------------------------------------
-- Project    : RHINO SDR Processing Blocks
----------------------------------------------------------------------------
--
--	Author     : Lekhobola Tsoeunyane
-- Company    : University Of Cape Town
-- Email		  : lekhobola@gmail.com
----------------------------------------------------------------------------
-- Revisions : 
----------------------------------------------------------------------------
-- Features
-- 1) SPI configuration of ADS62P49, DAC3283, CDCE72010, ADS4249 and AMC7823
-- 2) LVDS interface to ADS62P49 and DAC3283
-- 2) ADS62P49 auto-calibration
-- 
-----------------------------------------------------------------------------
-- Library declarations
-----------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_misc.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_1164.all;
library unisim;
  use unisim.vcomponents.all;

------------------------------------------------------------------------------
-- Entity declaration
------------------------------------------------------------------------------
entity fmc150_if is
port (

	--RHINO Resources
	sysrst	        : in  std_logic; 
	clk_100MHz       : in  std_logic;
	mmcm_locked      : in  std_logic;

	clk_61_44MHz     : in  std_logic;
	clk_122_88MHz    : in  std_logic;
	mmcm_adac_locked : in  std_logic;
	
	dac_fpga_clk     : out std_logic;

	-------------- user design interface -----------------------
	-- ADC 
	adc_cha_dout     : out    std_logic_vector(13 downto 0);
	adc_chb_dout     : out    std_logic_vector(13 downto 0);

	-- DAC
	dac_chc_din      : in   std_logic_vector(15 downto 0);
	dac_chd_din      : in   std_logic_vector(15 downto 0);

	calibration_ok   : out  std_logic;
	
	-------------- physical external interface -----------------

	--Clock/Data connection to ADC on FMC150 (ADS62P49)
	clk_ab_p         : in    std_logic;
	clk_ab_n         : in    std_logic;
	cha_p            : in    std_logic_vector(6 downto 0);
	cha_n            : in    std_logic_vector(6 downto 0);
	chb_p            : in    std_logic_vector(6 downto 0);
	chb_n            : in    std_logic_vector(6 downto 0);

	--Clock/Data connection to DAC on FMC150 (DAC3283)
	dac_dclk_p       : out   std_logic;
	dac_dclk_n       : out   std_logic;
	dac_data_p       : out   std_logic_vector(7 downto 0);
	dac_data_n       : out   std_logic_vector(7 downto 0);
	dac_frame_p      : out   std_logic;
	dac_frame_n      : out   std_logic;
	txenable         : out   std_logic;

	--Clock/Trigger connection to FMC150
	clk_to_fpga      : in    std_logic;
	ext_trigger      : in    std_logic;

	--Serial Peripheral Interface (SPI)
	spi_sclk         : out   std_logic; -- Shared SPI clock line
	spi_sdata        : out   std_logic; -- Shared SPI sata line

	-- ADC specific signals
	adc_n_en         : out   std_logic; -- SPI chip select
	adc_sdo          : in    std_logic; -- SPI data out
	adc_reset        : out   std_logic; -- SPI reset

	-- CDCE specific signals
	cdce_n_en        : out   std_logic; -- SPI chip select
	cdce_sdo         : in    std_logic; -- SPI data out
	cdce_n_reset     : out   std_logic;
	cdce_n_pd        : out   std_logic;
	ref_en           : out   std_logic;
	pll_status       : in    std_logic;

	-- DAC specific signals
	dac_n_en         : out   std_logic; -- SPI chip select
	dac_sdo          : in    std_logic; -- SPI data out

	-- Monitoring specific signals
	mon_n_en         : out   std_logic; -- SPI chip select
	mon_sdo          : in    std_logic; -- SPI data out
	mon_n_reset      : out   std_logic;
	mon_n_int        : in    std_logic;

	--FMC Present status
	nfmc0_prsnt      : in    std_logic

	-- debug signals
);
end fmc150_if;

architecture rtl of fmc150_if is

	----------------------------------------------------------------------------------------------------
	-- Constant declaration
	----------------------------------------------------------------------------------------------------
	constant CLK_IDELAY : integer := 0; -- Initial number of delay taps on ADC clock input
	constant CHA_IDELAY : integer := 0; -- Initial number of delay taps on ADC data port A -- error-free capture range measured between 20 ... 30
	constant CHB_IDELAY : integer := 0; -- Initial number of delay taps on ADC data port B -- error-free capture range measured between 20 ... 30
	constant MAX_PATTERN_CNT : integer := 600;--16383; -- value of 15000 = approx 1 sec for ramp of length 2^14 samples @ 245.76 MSPS

	-- Define the phase increment word for the DDC and DUC blocks (aka NCO)
	-- dec2bin(round(Fc/Fs*2^28)), where Fc = -12 MHz, Fs = 61.44 MHz
	--constant FREQ_DEFAULT : std_logic_vector(27 downto 0) := x"CE00000";
	constant FREQ_DEFAULT : std_logic_vector(27 downto 0) := x"3200000";

	component mmcm_adac
	port
	 (-- Clock in ports
	  CLK_IN1           : in     std_logic;
	  -- Clock out ports
	  CLK_OUT1          : out    std_logic;
	  CLK_OUT2          : out    std_logic;
	  CLK_OUT3          : out    std_logic;
	  -- Status and control signals
	  RESET             : in     std_logic;
	  LOCKED            : out    std_logic
	 );
	end component;

	-- The following code must appear in the VHDL architecture header:
	------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
	component MMCM
	port
	 (-- Clock in ports
	  CLK_IN1           : in     std_logic;
	  -- Clock out ports
	  CLK_OUT1          : out    std_logic;
	  CLK_OUT2          : out    std_logic;
	  CLK_OUT3          : out    std_logic;
	  -- Status and control signals
	  RESET             : in     std_logic;
	  LOCKED            : out    std_logic
	 );
	end component;

	component fmc150_spi_ctrl is
	port (
	  init_done			 : out std_logic;

	  rd_n_wr          : in    std_logic;
	  addr             : in    std_logic_vector(15 downto 0);
	  idata            : in    std_logic_vector(31 downto 0);
	  odata            : out   std_logic_vector(31 downto 0);
	  busy             : out   std_logic;

	  cdce72010_valid  : in    std_logic;
	  ads62p49_valid   : in    std_logic;
	  dac3283_valid    : in    std_logic;
	  amc7823_valid    : in    std_logic;

	  rst              : in    std_logic;
	  clk              : in    std_logic;
	  external_clock   : in    std_logic;

	  spi_sclk         : out   std_logic;
	  spi_sdata        : out   std_logic;

	  adc_n_en         : out   std_logic;
	  adc_sdo          : in    std_logic;
	  adc_reset        : out   std_logic;

	  cdce_n_en        : out   std_logic;
	  cdce_sdo         : in    std_logic;
	  cdce_n_reset     : out   std_logic;
	  cdce_n_pd        : out   std_logic;
	  ref_en           : out   std_logic;
	  pll_status       : in    std_logic;

	  dac_n_en         : out   std_logic;
	  dac_sdo          : in    std_logic;

	  mon_n_en         : out   std_logic;
	  mon_sdo          : in    std_logic;
	  mon_n_reset      : out   std_logic;
	  mon_n_int        : in    std_logic;

	  prsnt_m2c_l      : in    std_logic
	  

	);
	end component fmc150_spi_ctrl;


	component dac3283_serializer is
		port(
			--System Control Inputs
			RST_I          : in  STD_LOGIC;
			--Signal Channel Inputs
			DAC_CLK_O      : out STD_LOGIC;
			DAC_CLK_DIV4_O : out STD_LOGIC;
			DAC_READY      : out STD_LOGIC;
			CH_C_I         : in  STD_LOGIC_VECTOR(15 downto 0);
			CH_D_I         : in  STD_LOGIC_VECTOR(15 downto 0);
			-- DAC interface
			FMC150_CLK     : in  STD_LOGIC;
			DAC_DCLK_P     : out STD_LOGIC;
			DAC_DCLK_N     : out STD_LOGIC;
			DAC_DATA_P     : out STD_LOGIC_VECTOR(7 downto 0);
			DAC_DATA_N     : out STD_LOGIC_VECTOR(7 downto 0);
			FRAME_P        : out STD_LOGIC;
			FRAME_N        : out STD_LOGIC;
			-- Testing
			IO_TEST_EN     : in  STD_LOGIC
		);
	end component dac3283_serializer;

	component ADC_auto_calibration is
	  generic (
		  MAX_PATTERN_CNT : integer := 1000;   -- value of 15000 = approx 1 sec for ramp of length 2^14 samples @ 245.76 MSPS
		  INIT_IDELAY : integer                -- Initial number of delay taps on ADC data port
		);
	  Port ( 
		  reset                 : in  STD_LOGIC;
		  clk                   : in  STD_LOGIC;
		  ADC_calibration_start : in  STD_LOGIC;
		  ADC_data              : in  STD_LOGIC_VECTOR (13 downto 0);
		  re_mux_polarity       : out  STD_LOGIC;
		  trace_edge            : out  STD_LOGIC;
		  ADC_calibration_state : out  STD_LOGIC_VECTOR(2 downto 0);
		  iDelay_cnt            : out  STD_LOGIC_VECTOR (4 downto 0);
		  iDelay_inc_en		   : out  std_logic;
		  ADC_calibration_done  : out  BOOLEAN;
		  ADC_calibration_good  : out  STD_LOGIC);
	end component;
	
	----------------------------------------------------------------------------------------------------
	-- Debugging Components and Signals
	----------------------------------------------------------------------------------------------------
	component icon
	  PORT (
		 CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		 CONTROL1 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		 CONTROL2 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));

	end component;

	component ila0
	  PORT (
		 CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		 CLK : IN STD_LOGIC;
		 DATA : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		 TRIG0 : IN STD_LOGIC_VECTOR(3 DOWNTO 0));

	end component;

	component ila1
	  PORT (
		 CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		 CLK : IN STD_LOGIC;
		 DATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
		 TRIG0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0));

	end component;

	component vio
	  PORT (
		 CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		 ASYNC_OUT : OUT STD_LOGIC_VECTOR(7 DOWNTO 0));

	end component;

	signal CONTROL0 : STD_LOGIC_VECTOR(35 DOWNTO 0);
	signal CONTROL1 : STD_LOGIC_VECTOR(35 DOWNTO 0);
	signal CONTROL2 : STD_LOGIC_VECTOR(35 DOWNTO 0);
	signal ila_data0 :  STD_LOGIC_VECTOR(15 DOWNTO 0);
	signal ila_data1 :  STD_LOGIC_VECTOR(127 DOWNTO 0);
	signal trig0 : STD_LOGIC_VECTOR(3 DOWNTO 0);
	signal trig1 : STD_LOGIC_VECTOR(7 DOWNTO 0);
	signal vio_data :  STD_LOGIC_VECTOR(7 DOWNTO 0);

	----------------------------------------------------------------------------------------------------
	-- End
	----------------------------------------------------------------------------------------------------

	----------------------------------------------------------------------------------------------------
	-- Signal declaration
	----------------------------------------------------------------------------------------------------
	--signal clk_100Mhz        : std_logic;
	--signal clk_200Mhz        : std_logic;
	--signal mmcm_locked       : std_logic;

	signal arst              : std_logic := '0';
	signal rst               : std_logic;
	signal rst_duc_ddc       : std_logic;

	signal clk_ab_l          : std_logic;
	signal clk_ab_dly        : std_logic;
	signal clk_ab_i          : std_logic;

	signal cha_ddr           : std_logic_vector(6 downto 0);  -- Double Data Rate
	signal cha_ddr_dly       : std_logic_vector(6 downto 0);  -- Double Data Rate, Delayed
	signal cha_sdr           : std_logic_vector(13 downto 0); -- Single Data Rate

	signal chb_ddr           : std_logic_vector(6 downto 0);  -- Double Data Rate
	signal chb_ddr_dly       : std_logic_vector(6 downto 0);  -- Double Data Rate, Delayed
	signal chb_sdr           : std_logic_vector(13 downto 0); -- Single Data Rate

	signal adc_dout_i        : std_logic_vector(13 downto 0); -- Single Data Rate, Extended to 16-bit
	signal adc_dout_q        : std_logic_vector(13 downto 0); -- Single Data Rate, Extended to 16-bit
	signal adc_vout          : std_logic;

	signal freq              : std_logic_vector(27 downto 0);
	signal cmplx_aresetn_duc : std_logic;
	signal dds_reset_duc     : std_logic;
	signal cmplx_aresetn_ddc : std_logic;
	signal dds_reset_ddc     : std_logic;

	signal signal_ce         : std_logic;
	signal signal_ce_prev    : std_logic;
	signal signal_vout       : std_logic;

	signal imp_dout_i        : std_logic_vector(15 downto 0);
	signal imp_dout_q        : std_logic_vector(15 downto 0);

	signal delay_update      : std_logic;
	signal clk_cntvaluein    : std_logic_vector(4 downto 0);
	signal cha_cntvaluein    : std_logic_vector(4 downto 0);
	signal chb_cntvaluein    : std_logic_vector(4 downto 0);

	signal clk_cntvalueout   : std_logic_vector(4 downto 0);
	type cha_cntvalueout_array is array(cha_p'length-1 downto 0) of std_logic_vector(4 downto 0);
	signal cha_cntvalueout   : cha_cntvalueout_array;
	type chb_cntvalueout_array is array(chb_p'length-1 downto 0) of std_logic_vector(4 downto 0);
	signal chb_cntvalueout   : chb_cntvalueout_array;

	signal rd_n_wr           : std_logic;
	signal addr              : std_logic_vector(15 downto 0);
	signal idata             : std_logic_vector(31 downto 0);
	signal odata             : std_logic_vector(31 downto 0);
	signal busy              : std_logic;
	signal cdce72010_valid   : std_logic;
	signal ads62p49_valid    : std_logic;
	signal dac3283_valid     : std_logic;
	signal amc7823_valid     : std_logic;

	--signal clk_66MHz         : std_logic;
	--signal clk_61_44MHz      : std_logic;
	signal clk_61_44MHz_n    : std_logic;
	--signal clk_122_88MHz     : std_logic;
	--signal clk_368_64MHz     : std_logic;
	--signal mmcm_adac_locked  : std_logic;


	signal dac_din_i         : std_logic_vector(15 downto 0);
	signal dac_din_q         : std_logic_vector(15 downto 0);

	signal frame             : std_logic;
	signal io_rst            : std_logic;

	signal dac_dclk_prebuf   : std_logic;
	signal dac_data_prebuf   : std_logic_vector(7 downto 0);
	signal dac_frame_prebuf  : std_logic;

	signal digital_mode      : std_logic;
	signal external_clock    : std_logic := '0';

	signal ADC_cha_calibration_start       : std_logic;
	signal ADC_chb_calibration_start       : std_logic;
	signal ADC_cha_calibration_done        : boolean;
	signal ADC_cha_calibration_done_r      : boolean;
	signal ADC_cha_calibration_done_rr     : boolean;
	signal ADC_chb_calibration_done        : boolean;
	signal ADC_chb_calibration_done_r      : boolean;
	signal ADC_chb_calibration_done_rr     : boolean;
	signal ADC_chb_calibration_test_pattern_mode_command_sent : boolean;
	signal ADC_cha_calibration_test_pattern_mode_command_sent : boolean;
	signal ADC_chb_normal_mode_command_sent : boolean;
	signal ADC_cha_normal_mode_command_sent : boolean;
	signal ADC_chb_trace_edge              : std_logic;
	signal ADC_cha_trace_edge              : std_logic;
	signal ADC_chb_calibration_state       : std_logic_vector(2 downto 0);
	signal ADC_cha_calibration_state       : std_logic_vector(2 downto 0);
	signal ADC_chb_calibration_good	      : std_logic;
	signal ADC_cha_calibration_good	      : std_logic;
	signal ADC_calibration_good	         : std_logic;
	signal ADC_chb_ready                   : boolean;
	signal ADC_cha_ready                   : boolean;
	signal ADC_ready                       : boolean;
	signal cha_cntvaluein_update    : std_logic_vector(4 downto 0);
	signal clk_cntvaluein_update    : std_logic_vector(4 downto 0);
	signal fmc150_spi_ctrl_done	: std_logic;
	signal fmc150_spi_ctrl_done_r	: std_logic;

	signal sysclk		: std_logic;

	signal busy_reg	: std_logic;
	signal cha_cntvaluein_update_61_44MHz    : std_logic_vector(4 downto 0);
	signal cha_cntvaluein_update_100MHz    : std_logic_vector(4 downto 0);
	signal chb_cntvaluein_update    : std_logic_vector(4 downto 0);
	signal chb_cntvaluein_update_vio    : std_logic_vector(4 downto 0);
	signal chb_cntvaluein_update_61_44MHz    : std_logic_vector(4 downto 0);
	signal chb_cntvaluein_update_100MHz    : std_logic_vector(4 downto 0);

	signal adc_dout_i_prev   : std_logic_vector(13 downto 0);
	signal adc_dout_61_44_MSPS_valid	 : std_logic;
	signal clk_61_44MHz_count 			 : std_logic;

	signal adc_cha_re_mux_polarity 	 : std_logic := '1';	-- initial state '1' is contrary to actual default behaviour in hardware, but desired for simulation to verify correctness of state machine
	signal adc_chb_re_mux_polarity 	 : std_logic := '1';	-- initial state '1' is contrary to actual default behaviour in hardware, but desired for simulation to verify correctness of state machine

	signal sclk					 : std_logic;
	signal sclk_n				 : std_logic;

	signal ce_a 				 : std_logic := '0';
	signal ce_b 				 : std_logic := '0';
	signal cha_inc_update		     : std_logic;
	signal cha_inc_update_100MHz    : std_logic; 
	signal cha_inc_update_61_44MHz  : std_logic;
	signal cha_incin					  : std_logic;
	signal chb_inc_update		     : std_logic;
	signal chb_inc_update_100MHz    : std_logic; 
	signal chb_inc_update_61_44MHz  : std_logic;
	signal chb_incin					  : std_logic;
	signal dac_ready					  : std_logic;

	signal txen    		 : std_logic := '0';
	signal dac_cnt        : std_logic_vector(13 downto 0) := (others => '0');
	--signal dac_sample_clk : std_logic;
	signal ftw				 : std_logic_vector(31 downto 0);

	----------------------------------------------------------------------------------------------------
	-- Begin
	----------------------------------------------------------------------------------------------------
begin



	----------------------------------------------------------------------------------
	-- Perform ADC auto calibration
	----------------------------------------------------------------------------------
	routing_to_SPI: process (arst, clk_100Mhz)
	begin
		if (arst = '1') then
			busy_reg <= '0';
			cdce72010_valid	<= '0';
			ads62p49_valid		<= '0';
			dac3283_valid		<= '0';
			amc7823_valid		<= '0';
			cha_cntvaluein_update_100MHz <= conv_std_logic_vector(CHA_IDELAY, 5);
			cha_cntvaluein_update <= conv_std_logic_vector(CHA_IDELAY, 5);
			chb_cntvaluein_update_100MHz <= conv_std_logic_vector(CHB_IDELAY, 5);
			chb_cntvaluein_update <= conv_std_logic_vector(CHB_IDELAY, 5);
			clk_cntvaluein_update <= conv_std_logic_vector(CLK_IDELAY, 5);
			ADC_chb_calibration_done_r <= FALSE;
			ADC_chb_calibration_done_rr <= FALSE;
			ADC_cha_calibration_done_r <= FALSE;
			ADC_cha_calibration_done_rr <= FALSE;
			ADC_chb_calibration_test_pattern_mode_command_sent <= FALSE;
			ADC_cha_calibration_test_pattern_mode_command_sent <= FALSE;
			ADC_chb_normal_mode_command_sent <= FALSE;
			ADC_cha_normal_mode_command_sent <= FALSE;
			ADC_chb_calibration_start <= '0';
			ADC_cha_calibration_start <= '0';
			fmc150_spi_ctrl_done_r <= '0';
			ADC_cha_ready <= FALSE;
			ADC_chb_ready <= FALSE;
			ADC_ready <= FALSE;
		elsif (rising_edge(clk_100Mhz)) then
			busy_reg <= busy;
			fmc150_spi_ctrl_done_r <= fmc150_spi_ctrl_done;
			ADC_chb_calibration_done_r <= ADC_chb_calibration_done;									-- double-register to cross from clock domain of 'ADC_auto_calibration'
			ADC_chb_calibration_done_rr <= ADC_chb_calibration_done_r;								-- where 'ADC_chb_calibration_done' is set
			ADC_chb_calibration_done_rr <= TRUE;
			ADC_cha_calibration_done_r <= ADC_cha_calibration_done;
			ADC_cha_calibration_done_rr <= ADC_cha_calibration_done_r;
			-------------------Debugging-------------
			--ADC_chb_ready <= TRUE;
			-------------------Debugging-------------
			if not ADC_chb_ready then
				chb_cntvaluein_update_100MHz <= chb_cntvaluein_update_61_44MHz;
				chb_cntvaluein_update <= chb_cntvaluein_update_100MHz;
				chb_inc_update_100MHz <= chb_inc_update_61_44MHz;
				chb_inc_update  		 <= chb_inc_update_100MHz;
				if not ADC_chb_calibration_done_rr then
					if not ADC_chb_calibration_test_pattern_mode_command_sent then 
						if (fmc150_spi_ctrl_done = '1' and fmc150_spi_ctrl_done_r = '0') then	-- rising edge of 'fmc150_spi_ctrl_done' indicates reset-time
																														-- initialization of FMC150 SPI devices has completed
							addr <= x"0075";
							idata <= x"00000004";																-- send SPI command to ads62p49 for test-mode / ramp pattern on Ch B
							rd_n_wr <= '0';
							ads62p49_valid <= not ads62p49_valid;											-- toggle triggers transaction with SPI device on FMC150
							ADC_chb_calibration_test_pattern_mode_command_sent <= TRUE;
						else
							ads62p49_valid <= ads62p49_valid;
							ADC_chb_calibration_test_pattern_mode_command_sent <= FALSE;					
						end if;
					else
						if (busy = '0' and busy_reg = '1') then	-- wait for falling edge of 'busy' indicating SPI port has sent command to ADS62P49 for test-mode
							ADC_chb_calibration_start <= '1'; 			-- ... ADC auto-calibration state-machine 'ADC_auto_calibration' is awaiting this event to start
						else
							ADC_chb_calibration_start <= '0';
						end if;
					end if;
				else
					if not ADC_chb_normal_mode_command_sent then
						addr <= x"0075";
						idata <= x"00000000";																	-- send SPI command to ads62p49 for normal capture mode
						rd_n_wr <= '0';
						ads62p49_valid <= not ads62p49_valid;												-- toggle triggers transaction with SPI device on FMC150
						ADC_chb_normal_mode_command_sent <= TRUE;
					else
						if (busy = '0' and busy_reg = '1') then		-- wait for falling edge of 'busy' indicating SPI port has sent command to ADS62P49 to resume normal capture mode after ADC calibration sequence
							ADC_chb_ready <= TRUE;																	-- ADC auto-calibration is done and ADS62P49 is now in normal capture mode ... allow RX FIFO to read
						else
							ADC_chb_ready <= FALSE;
						end if;
					end if;
				end if;
			elsif not ADC_cha_ready then
				cha_cntvaluein_update_100MHz <= cha_cntvaluein_update_61_44MHz;
				cha_cntvaluein_update <= cha_cntvaluein_update_100MHz;
				cha_inc_update_100MHz <= cha_inc_update_61_44MHz;
				cha_inc_update  		 <= cha_inc_update_100MHz;
				if not ADC_cha_calibration_done_rr then
					if not ADC_cha_calibration_test_pattern_mode_command_sent then 
						addr <= x"0062";
						idata <= x"00000004";																-- send SPI command to ads62p49 for test-mode / ramp pattern on Ch A
						rd_n_wr <= '0';
						ads62p49_valid <= not ads62p49_valid;											-- toggle triggers transaction with SPI device on FMC150
						ADC_cha_calibration_test_pattern_mode_command_sent <= TRUE;
					else
						if (busy = '0' and busy_reg = '1') then	-- wait for falling edge of 'busy' indicating SPI port has sent command to ADS62P49 for test-mode
							ADC_cha_calibration_start <= '1'; 			-- ... ADC auto-calibration state-machine 'ADC_auto_calibration' is awaiting this event to start
						else
							ADC_cha_calibration_start <= '0';
						end if;
					end if;
				else
					if not ADC_cha_normal_mode_command_sent then
						addr <= x"0062";
						idata <= x"00000000";																	-- send SPI command to ads62p49 for normal capture mode
						rd_n_wr <= '0';
						ads62p49_valid <= not ads62p49_valid;												-- toggle triggers transaction with SPI device on FMC150
						ADC_cha_normal_mode_command_sent <= TRUE;
					else
						if (busy = '0' and busy_reg = '1') then		-- wait for falling edge of 'busy' indicating SPI port has sent command to ADS62P49 to resume normal capture mode after ADC calibration sequence
							ADC_cha_ready <= TRUE;																-- ADC auto-calibration is done and ADS62P49 is now in normal capture mode
							ADC_ready <= TRUE;                                                   -- allow RX FIFO to read
						else
							ADC_cha_ready <= FALSE;
							ADC_ready <= FALSE;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process routing_to_SPI;

	calibration_ok <= '1' when ADC_cha_calibration_done_r and ADC_chb_calibration_done_r else
							'0';
	
	----------------------------------------------------------------------------------
	-- Update iDelay values for incoming ADC data, clock
	----------------------------------------------------------------------------------

	iDelay_update: process (arst, clk_100Mhz)
	begin
	  if (arst = '1') then
		 delay_update   <= '1';
		 clk_cntvaluein <= conv_std_logic_vector(CLK_IDELAY, 5);
		 cha_cntvaluein <= conv_std_logic_vector(CHA_IDELAY, 5);
		 chb_cntvaluein <= conv_std_logic_vector(CHB_IDELAY, 5);
		 cha_incin <= '0';
		 chb_incin <= '0';
	  elsif (rising_edge(clk_100Mhz)) then
	  
		 -- Generate an delay_update pulse in case one of the cntvaluein values has changed
		 if (cha_cntvaluein /= cha_cntvaluein_update) then
			delay_update   <= '1';
			clk_cntvaluein <= clk_cntvaluein;
			chb_cntvaluein <= chb_cntvaluein;
			cha_cntvaluein <= cha_cntvaluein_update;
			chb_incin	   <= '0'; 
			cha_incin	   <= cha_inc_update;
		 elsif (chb_cntvaluein /= chb_cntvaluein_update) then
			delay_update   <= '1';
			clk_cntvaluein <= clk_cntvaluein;
			chb_cntvaluein <= chb_cntvaluein_update;
			cha_cntvaluein <= cha_cntvaluein;
			chb_incin	   <= chb_inc_update; 
			cha_incin	   <= '0';
		 elsif (clk_cntvaluein /= clk_cntvaluein_update) then
			delay_update   <= '1';
			clk_cntvaluein <= clk_cntvaluein_update;
			chb_cntvaluein <= chb_cntvaluein;
			cha_cntvaluein <= cha_cntvaluein;
			chb_incin	   <= '0'; 
			cha_incin	   <= '0';
		 else
			delay_update   <= '0';
			clk_cntvaluein <= clk_cntvaluein;
			chb_cntvaluein <= chb_cntvaluein;
			cha_cntvaluein <= cha_cntvaluein;
			chb_incin	   <= '0'; 
			cha_incin	   <= '0';
		 end if;
	  end if;
	end process iDelay_update;


	----------------------------------------------------------------------------------
	-- ADC calibration Channel B
	----------------------------------------------------------------------------------

	ADC_auto_calibration_chB: ADC_auto_calibration
	 generic map(
			  MAX_PATTERN_CNT => MAX_PATTERN_CNT,
			  INIT_IDELAY => CHB_IDELAY
			)
	 Port map( 
			  reset => arst,
			  clk => clk_61_44Mhz,
			  ADC_calibration_start => ADC_chb_calibration_start,
			  ADC_data => adc_dout_q,
			  re_mux_polarity => adc_chb_re_mux_polarity,
			  trace_edge => ADC_chb_trace_edge,
			  ADC_calibration_state => ADC_chb_calibration_state,
			  iDelay_cnt => chb_cntvaluein_update_61_44MHz,
			  iDelay_inc_en => chb_inc_update_61_44MHz,
			  ADC_calibration_done => ADC_chb_calibration_done,
			  ADC_calibration_good => ADC_chb_calibration_good);

	----------------------------------------------------------------------------------
	-- ADC calibration Channel A
	----------------------------------------------------------------------------------

	ADC_auto_calibration_chA: ADC_auto_calibration
	 generic map(
			  MAX_PATTERN_CNT => MAX_PATTERN_CNT,
			  INIT_IDELAY => CHA_IDELAY
			)
	 Port map(
			  reset => arst,
			  clk => clk_61_44Mhz,
			  ADC_calibration_start => ADC_cha_calibration_start,
			  ADC_data => adc_dout_i,
			  re_mux_polarity => adc_cha_re_mux_polarity,
			  trace_edge => ADC_cha_trace_edge,
			  ADC_calibration_state => ADC_cha_calibration_state,
			  iDelay_cnt => cha_cntvaluein_update_61_44MHz,
			  iDelay_inc_en => cha_inc_update_61_44MHz,
			  ADC_calibration_done => ADC_cha_calibration_done,
			  ADC_calibration_good => ADC_cha_calibration_good);

	ADC_calibration_good <= ADC_chb_calibration_good AND ADC_cha_calibration_good;
	----------------------------------------------------------------------------------------------------
	-- IDELAY Control
	----------------------------------------------------------------------------------------------------
	ce_a <= cha_incin;
	ce_b <= chb_incin;

	arst <= vio_data(0) or not mmcm_locked;
	--arst <= vio_data(0);

	clk_61_44MHz_n <= not clk_61_44MHz;
	----------------------------------------------------------------------------------------------------
	-- Reset sequence
	----------------------------------------------------------------------------------------------------
	process (mmcm_adac_locked, clk_61_44MHz)
	  variable cnt : integer range 0 to 1023 := 0;
	begin
	  if (mmcm_adac_locked = '0') then
		 rst <= '1';
		 io_rst <= '0';
		 frame <= '0';
		 txenable <= '0';

		  elsif (rising_edge(clk_61_44MHz)) then
			 -- Finally the TX enable for the DAC can by pulled high.
			 -- DDC and DUC are kept in reset state for a while...
		 if (cnt < 1023) then
			cnt := cnt + 1;
			rst <= '1';
		 else
			cnt := cnt;
			rst <= '0';
		 end if;

		 -- The OSERDES blocks are synchronously reset for one clock cycle...
		 if (cnt = 255) then
			io_rst <= '1';
		 else
			io_rst <= '0';
		 end if;	 
		 
		 if (cnt = 1023) then
			txenable <= '1';
			txen <= '1';
		 end if;
	  end if;
	end process;

	----------------------------------------------------------------------------------------------------
	-- Channel A data from ADC
	----------------------------------------------------------------------------------------------------
	adc_data_a: for i in 0 to 6 generate

	  -- Differantial input buffer with termination (LVDS)
	  ibufds_inst : ibufds
	  generic map (
		 IOSTANDARD => "LVDS_25",
		 DIFF_TERM  => TRUE
	  )
	  port map (
		 i  => cha_p(i),
		 ib => cha_n(i),
		 o  => cha_ddr(i)
	  );

	-- Input delay
	  iodelay_inst : iodelay2
	  generic map (
		 DATA_RATE          => "DDR",
		 IDELAY_VALUE       => CHA_IDELAY,
		 IDELAY_TYPE        => "VARIABLE_FROM_ZERO",
		 COUNTER_WRAPAROUND => "STAY_AT_LIMIT",
		 DELAY_SRC          => "IDATAIN",
		 SERDES_MODE        => "NONE",
		 SIM_TAPDELAY_VALUE => 75
	  )
	  port map (
		 idatain    => cha_ddr(i),
		 dataout    => cha_ddr_dly(i),
		 t          => '1',

		 odatain    => '0',

		 ioclk0     => clk_61_44MHz,
		 ioclk1     => clk_61_44MHz_n,
		 clk        => clk_61_44MHz,
		 cal        => '0',
		 inc        => cha_incin,
		 ce         => ce_a,
		 busy       => open,
		 rst        => sysrst
	  );
	  
		 -- DDR to SDR
	  iddr_inst_cha : IDDR2
	  generic map (
	  --  DDR_CLK_EDGE => "SAME_EDGE_PIPELINED"
		DDR_ALIGNMENT => "NONE",
		INIT_Q0 =>	'0',
		INIT_Q1 =>	'0',
		SRTYPE => "SYNC")
	  port map (
		 q0 => cha_sdr(2*i),
		 q1 => cha_sdr(2*i+1),
		 c0 => clk_61_44MHz,
		 c1 => clk_61_44MHz_n,	
		 ce => '1',
		 d  => cha_ddr_dly(i), 		   --cha_ddr_dly
		 r  => sysrst,
		 s  => '0'
	  );

	end generate;

	----------------------------------------------------------------------------------------------------
	-- Channel B data from ADC
	----------------------------------------------------------------------------------------------------
	adc_data_b: for i in 0 to 6 generate

	  -- Differantial input buffer with termination (LVDS)
	  ibufds_inst : ibufds
	  generic map (
		 IOSTANDARD => "LVDS_25",
		 DIFF_TERM  => TRUE
	  )
	  port map (
		 i  => chb_p(i),
		 ib => chb_n(i),
		 o  => chb_ddr(i)
	  );


		-- Input delay
	  iodelay_inst : iodelay2
	  generic map (
		 DATA_RATE          => "DDR",
		 IDELAY_VALUE       => CHB_IDELAY,
		 IDELAY_TYPE        => "VARIABLE_FROM_ZERO",
		 COUNTER_WRAPAROUND => "STAY_AT_LIMIT",
		 DELAY_SRC          => "IDATAIN",
		 SERDES_MODE        => "NONE",
		 SIM_TAPDELAY_VALUE => 75
	  )
	  port map (
		 idatain    => chb_ddr(i),
		 dataout    => chb_ddr_dly(i),
		 t          => '1',

		 odatain    => '0',

		 ioclk0     => clk_61_44MHz,
		 ioclk1     => clk_61_44MHz_n,
		 clk        => clk_61_44MHz,
		 cal        => '0',
		 inc        => chb_incin,
		 ce         => ce_b,
		 busy       => open,
		 rst        => sysrst
	  );
	  
		  -- DDR to SDR
	  iddr_inst_chb : IDDR2
	  generic map (
	  --  DDR_CLK_EDGE => "SAME_EDGE_PIPELINED"
		DDR_ALIGNMENT => "NONE",
		INIT_Q0 =>	'0',
		INIT_Q1 =>	'0',
		SRTYPE => "SYNC")
	  port map (
		 q0 => chb_sdr(2*i),
		 q1 => chb_sdr(2*i+1),
		 c0 => clk_61_44MHz,
		 c1 => clk_61_44MHz_n,	
		 ce => '1',
		 d  => chb_ddr_dly(i), 		   --chb_ddr_dly
		 r  => sysrst,
		 s  => '0'
	  );
	end generate;

	----------------------------------------------------------------------------------------------------
	-- Ouput 16-bit digital samples
	----------------------------------------------------------------------------------------------------
	process (clk_61_44MHz)
	begin
	  if (rising_edge(clk_61_44MHz)) then
		 adc_cha_dout <= cha_sdr;
		 adc_chb_dout <= chb_sdr;
	  end if;
	end process;

	----------------------------------------------------------------------------------------------------
	-- Output MUX - Select data connected to the physical DAC interface
	----------------------------------------------------------------------------------------------------
	process (clk_61_44MHz)
	begin
	  if (rising_edge(clk_61_44MHz)) then		 
		 dac_cnt   <= dac_cnt + 1024;
	  end if;
	end process;
	
	----------------------------------------------------------------------------------------------------
	-- Output serdes and LVDS buffer for DAC clock
	----------------------------------------------------------------------------------------------------
	dac : dac3283_serializer
		port map(
			RST_I          => sysrst,
			DAC_CLK_O      => dac_fpga_clk,
			DAC_CLK_DIV4_O => open,
			DAC_READY      => dac_ready,
			CH_C_I         => dac_chc_din,
			CH_D_I         => dac_chd_din,
			FMC150_CLK     => clk_to_fpga,
			DAC_DCLK_P     => dac_dclk_p,
			DAC_DCLK_N     => dac_dclk_n,
			DAC_DATA_P     => dac_data_p,
			DAC_DATA_N     => dac_data_n,
			FRAME_P        => dac_frame_p,
			FRAME_N        => dac_frame_n,
			IO_TEST_EN     => '0' 
		);
		
	----------------------------------------------------------------------------------------------------
	-- Configuring the FMC150 card
	----------------------------------------------------------------------------------------------------
	-- the fmc150_spi_ctrl component configures the devices on the FMC150 card through the Serial
	-- Peripheral Interfaces (SPI) and some additional direct control signals.
	----------------------------------------------------------------------------------------------------
	fmc150_spi_ctrl_inst : fmc150_spi_ctrl
	port map (
		init_done		 => fmc150_spi_ctrl_done,

		rd_n_wr         => rd_n_wr,
		addr            => addr,
		idata           => idata,
		odata           => odata,
		busy            => busy,

		cdce72010_valid => cdce72010_valid,
		ads62p49_valid  => ads62p49_valid,
		dac3283_valid   => dac3283_valid,
		amc7823_valid   => amc7823_valid,

		rst             => arst,
		clk             => clk_100MHz,
		external_clock  => external_clock,

		spi_sclk        => sclk,
		spi_sdata       => spi_sdata,

		adc_n_en        => adc_n_en,
		adc_sdo         => adc_sdo,
		adc_reset       => adc_reset,

		cdce_n_en       => cdce_n_en,
		cdce_sdo        => cdce_sdo,
		cdce_n_reset    => cdce_n_reset,
		cdce_n_pd       => cdce_n_pd,
		ref_en          => ref_en,
		pll_status      => pll_status,

		dac_n_en        => dac_n_en,
		dac_sdo         => dac_sdo,

		mon_n_en        => mon_n_en,
		mon_sdo         => mon_sdo,
		mon_n_reset     => mon_n_reset,
		mon_n_int       => mon_n_int,

		prsnt_m2c_l     => nfmc0_prsnt
	);

	-- ODDR2 is needed instead of the following
		-- and limiting in Spartan 6
		txclk_ODDR2_inst : ODDR2
		generic map (
			DDR_ALIGNMENT => "NONE",
			INIT => '0',
			SRTYPE => "SYNC")
		port map (
			Q => spi_sclk, -- 1-bit DDR output data
			C0 => sclk, -- clock is your signal from PLL
			C1 => sclk_n, -- n
			D0 => '1', -- 1-bit data input (associated with C0)
			D1 => '0', -- 1-bit data input (associated with C1)
			R => sysrst, -- 1-bit reset input
			S => '0' -- 1-bit set input
		);
		sclk_n <= not sclk;
	-------------------------------------------END------------------------------------------------------
	 
	----------------------------------------------------------------------------------------------------
	-- Debugging Section
	----------------------------------------------------------------------------------------------------
	--  ila_data0(0) <= fmc150_spi_ctrl_done;
	--  ila_data0(1) <= external_clock;
	--  ila_data0(2) <= busy;
	--  ila_data0(3) <= mmcm_adac_locked;
	--  ila_data0(4) <= mmcm_locked;
	--  ila_data0(5) <= pll_status;
	--  ila_data0(6) <= '1' when ADC_cha_ready = TRUE else '0';
	--  ila_data0(7) <= '1' when ADC_chb_ready = TRUE else '0';
	--  ila_data0(8) <= txen;
	  
	--  ila_data1(13 downto 0) <= adc_dout_i;
	--  ila_data1(27 downto 14)<= adc_dout_q;  
	--  ila_data1(41 downto 28) <= dac_cnt;
	--  ila_data1(44 downto 42) <= ADC_chb_calibration_state;
	--  ila_data1(49 downto 45) <= cha_cntvaluein;
	--  ila_data1(50) <= ADC_calibration_good;
	  
	  --trig0(0) <= busy;--cmd_state(3 downto 0);--busy;--init_done;
	--  trig1(2 downto 0) <= ADC_chb_calibration_state;
	  
	------ instantiate chipscope components -------
	--	icon_inst : icon
	--	  port map (
	--		 CONTROL0 => CONTROL0,
	--		 CONTROL1 => CONTROL1,
	--		 CONTROL2 => CONTROL2
	--		 );

	--	ila_data0_inst : ila0
	--	  port map (
	--		 CONTROL => CONTROL0,
	--		 CLK     => clk_100MHz,--clk_245_76MHz,
	--		 DATA    => ila_data0,
	--		 TRIG0   => TRIG0);
			
	--	ila_data1_inst : ila1
	--	  port map (
	--		 CONTROL => CONTROL2,
	--		 CLK => clk_61_44MHz,
	--		 DATA => ila_data1,
	--		 TRIG0 => TRIG1);
			 
	--	vio_inst : vio
	--  port map (
	--	 CONTROL => CONTROL1,
	--	 ASYNC_OUT => vio_data);
	----------------------------------------------------------------------------------------------------
	-- End 
	----------------------------------------------------------------------------------------------------
end rtl;
