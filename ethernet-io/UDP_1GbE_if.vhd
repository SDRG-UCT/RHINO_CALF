----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:52:01 04/27/2015 
-- Design Name: 
-- Module Name:    UDP_1Gbe_Core - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity UDP_1GbE_if is
	port(
		GIGE_COL			: in std_logic;
		GIGE_CRS			: in std_logic;
		GIGE_MDC			: out std_logic;
		GIGE_MDIO		: inout std_logic;
		GIGE_TX_CLK	   : in std_logic;
		GIGE_nRESET	   : out std_logic;
		GIGE_RXD			: in std_logic_vector( 7 downto 0 );
		GIGE_RX_CLK		: in std_logic;
		GIGE_RX_DV		: in std_logic;
		GIGE_RX_ER		: in std_logic;
		GIGE_TXD			: out std_logic_vector( 7 downto 0 );
		GIGE_GTX_CLK 	: out std_logic;
		GIGE_TX_EN		: out std_logic;
		GIGE_TX_ER		: out std_logic;
		
		sys_clk_p      : in  std_logic;
		sys_clk_n      : in  std_logic;
		sys_rst_i      : in  std_logic
	);
end UDP_1GbE_if;

architecture Behavioral of UDP_1GbE_if is
	
	---------------------------------------------------------------------------
	--	Signal declaration section 
	---------------------------------------------------------------------------
	
	attribute S: string;
	attribute keep : string;
	
	attribute S of GIGE_RXD   : signal is "TRUE"; 
	attribute S of GIGE_RX_DV : signal is "TRUE";
	attribute S of GIGE_RX_ER : signal is "TRUE";	
	
	-- define constants
	constant UDP_TX_DATA_BYTE_LENGTH : integer := 128;
	constant UDP_RX_DATA_BYTE_LENGTH : integer := 37;
	constant TX_DELAY						: integer := 10;
	
	-- system control
	signal clk_125mhz   : std_logic;
	signal clk_100mhz    : std_logic;
	signal clk_25mhz    : std_logic;
	signal clk_6_25mhz  : std_logic;
	signal clk_3_125mhz : std_logic;
	signal reset        : std_logic;
	
	-- MAC signals
	signal udp_tx_pkt_data  : std_logic_vector (8 * UDP_TX_DATA_BYTE_LENGTH - 1 downto 0);
	signal udp_tx_pkt_vld : std_logic;
	signal udp_tx_pkt_sent  : std_logic;
	signal udp_tx_pkt_vld_r : std_logic;
	signal udp_tx_rdy		: std_logic;
			
	signal udp_rx_pkt_data  : std_logic_vector(8 * UDP_RX_DATA_BYTE_LENGTH - 1 downto 0);
	signal udp_rx_pkt_data_r: std_logic_vector(8 * UDP_RX_DATA_BYTE_LENGTH - 1 downto 0);
	signal udp_rx_pkt_req   : std_logic;
   signal udp_rx_rdy		: std_logic;
	signal udp_rx_rdy_r  : std_logic;
	
	signal dst_mac_addr     : std_logic_vector(47 downto 0);
	signal tx_state			: std_logic_vector(2 downto 0) := "000";
	signal rx_state			: std_logic_vector(2 downto 0) := "000";
	signal locked				: std_logic;
	signal mac_init_done		: std_logic;
	signal GIGE_GTX_CLK_r   : std_logic;
	signal GIGE_MDC_r			: std_logic;
	
	signal tx_delay_cnt		: integer := 0;
	
	---------------------------------------------------------------------------
	--	Component declaration section 
	---------------------------------------------------------------------------
	
	component UDP_1GbE is
	  generic(
			UDP_TX_DATA_BYTE_LENGTH : natural := 1;
			UDP_RX_DATA_BYTE_LENGTH : natural:= 1
	 );
	 port(
			-- user logic interface
			own_ip_addr		   : in std_logic_vector (31 downto 0);
			own_mac_addr      : in std_logic_vector (47 downto 0);
			dst_ip_addr       : in std_logic_vector (31 downto 0);
			dst_mac_addr      : out std_logic_vector(47 downto 0);

			udp_src_port  		: in std_logic_vector (15 downto 0);
			udp_dst_port      : in std_logic_vector (15 downto 0);

			udp_tx_pkt_data	: in  std_logic_vector (8 * UDP_TX_DATA_BYTE_LENGTH - 1 downto 0);
			udp_tx_pkt_vld    : in  std_logic;
			udp_tx_rdy			: out std_logic;

			udp_rx_pkt_data   : out std_logic_vector(8 * UDP_RX_DATA_BYTE_LENGTH - 1 downto 0);
			udp_rx_pkt_req    : in  std_logic;
			udp_rx_rdy		   : out std_logic;

			mac_init_done	   : out std_logic;

			udp_tx_clk_66mhz  : out std_logic;			
					
			-- MAC interface
			GIGE_COL			: in std_logic;
			GIGE_CRS			: in std_logic;
			GIGE_MDC			: out std_logic;
			GIGE_MDIO	   : inout std_logic;
			GIGE_TX_CLK	   : in std_logic;
			GIGE_nRESET	   : out std_logic;
			GIGE_RXD			: in std_logic_vector( 7 downto 0 );
			GIGE_RX_CLK		: in std_logic;
			GIGE_RX_DV		: in std_logic;
			GIGE_RX_ER		: in std_logic;
			GIGE_TXD			: out std_logic_vector( 7 downto 0 );
			GIGE_GTX_CLK 	: out std_logic;
			GIGE_TX_EN		: out std_logic;
			GIGE_TX_ER		: out std_logic;
			
			-- system control
			sys_clk_p      : in  std_logic;
			sys_clk_n      : in  std_logic;
			sys_rst_i      : in  std_logic;
			
			debug          : out std_logic_vector(2 downto 0)
	  );
	end component UDP_1GbE;
	
	---------------------------------------------------------------------------
	--							DUBUGGING SECTION
	---------------------------------------------------------------------------
	component icon
	PORT (
	 CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
	 CONTROL1 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));

	end component;

	
	component ila0
	PORT (
	 CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
	 CLK : IN STD_LOGIC;
	 DATA : IN STD_LOGIC_VECTOR(299 DOWNTO 0);
	 TRIG0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0));

	end component;

	component ila1
	  PORT (
		 CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		 CLK : IN STD_LOGIC;
		 DATA : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
		 TRIG0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0));

	end component;
	
	signal control0 : std_logic_vector(35 downto 0);
	signal control1 : std_logic_vector(35 downto 0);
	signal ila_data0 : std_logic_vector(299 downto 0);
	signal ila_data1 : std_logic_vector(63 downto 0);
	signal trig0    : std_logic_vector(7 downto 0);
	signal trig1    : std_logic_vector(7 downto 0);
	
	---------------------------------------------------------------------------
	--						END OF DUBUGGING SECTION
	---------------------------------------------------------------------------
begin

	UDP_1GbE_inst : UDP_1GbE 	  
	generic map(
			UDP_TX_DATA_BYTE_LENGTH => UDP_TX_DATA_BYTE_LENGTH,
			UDP_RX_DATA_BYTE_LENGTH => UDP_RX_DATA_BYTE_LENGTH
	 )
	port map(
			-- user logic interface
			own_ip_addr	=> x"c0a80003",
			own_mac_addr      => x"0024ba7d1d70",
			dst_ip_addr       => x"c0a80001",
			dst_mac_addr      => dst_mac_addr,
			
			udp_src_port  		=> x"26CA", --9930
			udp_dst_port      => x"26CA",
			
			udp_tx_pkt_data	=> udp_tx_pkt_data,
			udp_tx_pkt_vld    => udp_tx_pkt_vld,
			udp_tx_rdy		   => udp_tx_rdy,
			
			udp_rx_pkt_data   => udp_rx_pkt_data,
			udp_rx_pkt_req    => udp_rx_pkt_req,
			udp_rx_rdy		   => udp_rx_rdy,
			
			mac_init_done	   => mac_init_done,	

		   udp_tx_clk_66mhz  => clk_100mhz,
			
			-- MAC interface
			GIGE_COL			=> GIGE_COL,
			GIGE_CRS			=> GIGE_CRS,
			GIGE_MDC			=> GIGE_MDC,
			GIGE_MDIO	   => GIGE_MDIO,
			GIGE_TX_CLK	   => GIGE_TX_CLK,
			GIGE_nRESET	   => GIGE_nRESET,
			GIGE_RXD			=> GIGE_RXD,
			GIGE_RX_CLK		=> GIGE_RX_CLK,
			GIGE_RX_DV		=> GIGE_RX_DV,
			GIGE_RX_ER		=> GIGE_RX_ER,
			GIGE_TXD			=> GIGE_TXD,
			GIGE_GTX_CLK 	=> GIGE_GTX_CLK,
			GIGE_TX_EN		=> GIGE_TX_EN,
			GIGE_TX_ER		=> GIGE_TX_ER,
			
			-- system control
			sys_clk_p      => sys_clk_p,
			sys_clk_n      => sys_clk_n,
			sys_rst_i      => sys_rst_i
	  );	 
	  
		-----------------------------------------------------------------------
		--				UDP TRANSMISSION SECTION
		-----------------------------------------------------------------------
	  tx_proc : process(sys_rst_i,clk_100mhz)
	  begin
			if(sys_rst_i = '1') then
			elsif(rising_edge(clk_100mhz)) then
				case tx_state is
					when "000" =>
						tx_delay_cnt <= 0;
						if(udp_tx_rdy = '1') then
							tx_state <= "001";															
						end if;
					when "001" =>
						if(udp_tx_rdy = '1') then
							if(tx_delay_cnt = TX_DELAY) then
								tx_delay_cnt <= 0;
								udp_tx_pkt_vld_r <= '0';--'1';
								udp_tx_pkt_data  <= x"4833657a4769385670795139574134754e6563334e794d57685a4f5a346872697656315869796a71366a51463437525241333034734a72486567726f4d6f6c34486a4b4467696f484f6f67486d3073364b505348305a734f6a464a4b554d4e44775071416f526e4266366d50544c736c51736c78596b36335a584375666b3535";								
							else
							   udp_tx_pkt_vld_r <= '0';
								tx_delay_cnt <= tx_delay_cnt + 1;
							end if;
						else
							tx_state <= "000";	
						end if;
					when others =>
						null;
				end case;
			end if;
	  end process;
	  
	  udp_tx_pkt_vld <= udp_tx_pkt_vld_r;
	  
	  
	  -----------------------------------------------------------------------
		--				UDP RECEPTION SECTION
		-----------------------------------------------------------------------
	  rx_proc : process(sys_rst_i,clk_100mhz)
	  begin
			if(sys_rst_i = '1') then
			elsif(rising_edge(clk_100mhz)) then
				case rx_state is
					when "000" =>
						udp_rx_pkt_req <= '1';
						udp_rx_rdy_r <= udp_rx_rdy;
						rx_state <= "001";	
					when "001" =>
						if(udp_rx_rdy = '1') then
							udp_rx_pkt_data_r <= udp_rx_pkt_data;
							udp_rx_rdy_r <= udp_rx_rdy;
							rx_state <= "010";	
						end if;
					when "010" =>						
						udp_rx_pkt_data_r <= (others => '0');
						rx_state <= "000";	
						udp_rx_rdy_r <= udp_rx_rdy;
					when others =>
						null;
				end case;
			end if;
	  end process;
	   -----------------------------------------------------------------------
		--				DEBUGGING SECTION
		-----------------------------------------------------------------------
	--	icon_inst : icon
	--	port map (
	--	 CONTROL0 => CONTROL0,
	--	 CONTROL1 => CONTROL1);	
		 
	--	ila0_inst : ila0
	--	port map (
	--	 CONTROL => CONTROL0,
	--	 CLK => clk_100mhz,
	--	 DATA => ila_data0,
	--	 TRIG0 => TRIG0);
			 
	--	ila1_inst : ila1
	--	port map (
	--	 CONTROL => CONTROL1,
	--	 CLK => clk_125mhz,
	--	 DATA => ila_data1,
	--	 TRIG0 => TRIG1);
		 
	--	 ila_data0(0)  <= udp_rx_rdy_r;
	--	 ila_data0(1)  <= udp_rx_pkt_req;
	--	 ila_data0(297 downto 2) <= udp_rx_pkt_data_r;
		 
	--	 trig0(0) <= udp_rx_rdy;
		 	 
end Behavioral;

