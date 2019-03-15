-------------------------------------------------------------------------------
--  Department of Computer Engineering and Communications
--  Author: LPRS2  <lprs2@rt-rk.com>
--
--  Module Name: top
--
--  Description:
--
--    Simple test for VGA control
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity top is
  generic (
    RES_TYPE             : natural := 1;
    TEXT_MEM_DATA_WIDTH  : natural := 6;
    GRAPH_MEM_DATA_WIDTH : natural := 32
	 
    );
  port (
    clk_i          : in  std_logic;
    reset_n_i      : in  std_logic;
	 direct_mode_i : in std_logic;
	 display_mode_i : in std_logic_vector(1 downto 0);
	 
    -- vga
    vga_hsync_o    : out std_logic;
    vga_vsync_o    : out std_logic;
    blank_o        : out std_logic;
    pix_clock_o    : out std_logic;
    psave_o        : out std_logic;
    sync_o         : out std_logic;
    red_o          : out std_logic_vector(7 downto 0);
    green_o        : out std_logic_vector(7 downto 0);
    blue_o         : out std_logic_vector(7 downto 0)
   );
end top;

architecture rtl of top is

  constant RES_NUM : natural := 6;

  type t_param_array is array (0 to RES_NUM-1) of natural;
  
  constant H_RES_ARRAY           : t_param_array := ( 0 => 64, 1 => 640,  2 => 800,  3 => 1024,  4 => 1152,  5 => 1280,  others => 0 );
  constant V_RES_ARRAY           : t_param_array := ( 0 => 48, 1 => 480,  2 => 600,  3 => 768,   4 => 864,   5 => 1024,  others => 0 );
  constant MEM_ADDR_WIDTH_ARRAY  : t_param_array := ( 0 => 12, 1 => 14,   2 => 13,   3 => 14,    4 => 14,    5 => 15,    others => 0 );
  constant MEM_SIZE_ARRAY        : t_param_array := ( 0 => 48, 1 => 4800, 2 => 7500, 3 => 12576, 4 => 15552, 5 => 20480, others => 0 ); 
  
  constant H_RES          : natural := H_RES_ARRAY(RES_TYPE);
  constant V_RES          : natural := V_RES_ARRAY(RES_TYPE);
  constant MEM_ADDR_WIDTH : natural := MEM_ADDR_WIDTH_ARRAY(RES_TYPE);
  constant MEM_SIZE       : natural := MEM_SIZE_ARRAY(RES_TYPE);

  component vga_top is 
    generic (
      H_RES                : natural := 640;
      V_RES                : natural := 480;
      MEM_ADDR_WIDTH       : natural := 32;
      GRAPH_MEM_ADDR_WIDTH : natural := 32;
      TEXT_MEM_DATA_WIDTH  : natural := 32;
      GRAPH_MEM_DATA_WIDTH : natural := 32;
      RES_TYPE             : integer := 1;
      MEM_SIZE             : natural := 4800
      );
    port (
      clk_i               : in  std_logic;
      reset_n_i           : in  std_logic;
      --
      direct_mode_i       : in  std_logic; -- 0 - text and graphics interface mode, 1 - direct mode (direct force RGB component)
      dir_red_i           : in  std_logic_vector(7 downto 0);
      dir_green_i         : in  std_logic_vector(7 downto 0);
      dir_blue_i          : in  std_logic_vector(7 downto 0);
      dir_pixel_column_o  : out std_logic_vector(10 downto 0);
      dir_pixel_row_o     : out std_logic_vector(10 downto 0);
      -- mode interface
      display_mode_i      : in  std_logic_vector(1 downto 0);  -- 00 - text mode, 01 - graphics mode, 01 - text & graphics
      -- text mode interface
      text_addr_i         : in  std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
      text_data_i         : in  std_logic_vector(TEXT_MEM_DATA_WIDTH-1 downto 0);
      text_we_i           : in  std_logic;
      -- graphics mode interface
      graph_addr_i        : in  std_logic_vector(GRAPH_MEM_ADDR_WIDTH-1 downto 0);
      graph_data_i        : in  std_logic_vector(GRAPH_MEM_DATA_WIDTH-1 downto 0);
      graph_we_i          : in  std_logic;
      --
      font_size_i         : in  std_logic_vector(3 downto 0);
      show_frame_i        : in  std_logic;
      foreground_color_i  : in  std_logic_vector(23 downto 0);
      background_color_i  : in  std_logic_vector(23 downto 0);
      frame_color_i       : in  std_logic_vector(23 downto 0);
      -- vga
      vga_hsync_o         : out std_logic;
      vga_vsync_o         : out std_logic;
      blank_o             : out std_logic;
      pix_clock_o         : out std_logic;
      vga_rst_n_o         : out std_logic;
      psave_o             : out std_logic;
      sync_o              : out std_logic;
      red_o               : out std_logic_vector(7 downto 0);
      green_o             : out std_logic_vector(7 downto 0);
      blue_o              : out std_logic_vector(7 downto 0)
    );
  end component;
  
  component ODDR2
  generic(
   DDR_ALIGNMENT : string := "NONE";
   INIT          : bit    := '0';
   SRTYPE        : string := "SYNC"
   );
  port(
    Q           : out std_ulogic;
    C0          : in  std_ulogic;
    C1          : in  std_ulogic;
    CE          : in  std_ulogic := 'H';
    D0          : in  std_ulogic;
    D1          : in  std_ulogic;
    R           : in  std_ulogic := 'L';
    S           : in  std_ulogic := 'L'
  );
  end component;
  
  
  constant update_period     : std_logic_vector(31 downto 0) := conv_std_logic_vector(1, 32);
  
  constant GRAPH_MEM_ADDR_WIDTH : natural := MEM_ADDR_WIDTH + 6;-- graphics addres is scales with minumum char size 8*8 log2(64) = 6
  
  -- text
  signal message_lenght      : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
  signal graphics_lenght     : std_logic_vector(GRAPH_MEM_ADDR_WIDTH-1 downto 0);
  
  signal direct_mode         : std_logic;
  --
  signal font_size           : std_logic_vector(3 downto 0);
  signal show_frame          : std_logic;
  signal display_mode        : std_logic_vector(1 downto 0);  -- 01 - text mode, 10 - graphics mode, 11 - text & graphics
  signal foreground_color    : std_logic_vector(23 downto 0);
  signal background_color    : std_logic_vector(23 downto 0);
  signal frame_color         : std_logic_vector(23 downto 0);

  signal char_we             : std_logic;
  signal char_address        : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
  signal char_value          : std_logic_vector(5 downto 0);

  signal pixel_address       : std_logic_vector(GRAPH_MEM_ADDR_WIDTH-1 downto 0);
  signal pixel_value         : std_logic_vector(GRAPH_MEM_DATA_WIDTH-1 downto 0);
  signal pixel_we            : std_logic;

  signal pix_clock_s         : std_logic;
  signal vga_rst_n_s         : std_logic;
  signal pix_clock_n         : std_logic;
   
  signal dir_red             : std_logic_vector(7 downto 0);
  signal dir_green           : std_logic_vector(7 downto 0);
  signal dir_blue            : std_logic_vector(7 downto 0);
  signal dir_pixel_column    : std_logic_vector(10 downto 0);
  signal dir_pixel_row       : std_logic_vector(10 downto 0);
  
  signal sec_c					: std_logic_vector(24 downto 0);
  signal offset					: std_logic_vector (13 downto 0);
  signal sCT						:std_logic;
  signal offset1					: std_logic_vector (19 downto 0);
    signal sec_c1					: std_logic_vector(24 downto 0);

begin

  -- calculate message lenght from font size
  message_lenght <= conv_std_logic_vector(MEM_SIZE/64, MEM_ADDR_WIDTH)when (font_size = 3) else -- note: some resolution with font size (32, 64)  give non integer message lenght (like 480x640 on 64 pixel font size) 480/64= 7.5
                    conv_std_logic_vector(MEM_SIZE/16, MEM_ADDR_WIDTH)when (font_size = 2) else
                    conv_std_logic_vector(MEM_SIZE/4 , MEM_ADDR_WIDTH)when (font_size = 1) else
                    conv_std_logic_vector(MEM_SIZE   , MEM_ADDR_WIDTH);
  
  graphics_lenght <= conv_std_logic_vector(MEM_SIZE*8*8, GRAPH_MEM_ADDR_WIDTH);
  
  -- removed to inputs pin
  direct_mode <= '0';
  display_mode     <= "01";  -- 01 - text mode, 10 - graphics mode, 11 - text & graphics
  
  font_size        <= x"1";
  show_frame       <= '1';
  foreground_color <= x"FFFFFF";
  background_color <= x"000000";
  frame_color      <= x"FF0000";

  clk5m_inst : ODDR2
  generic map(
    DDR_ALIGNMENT => "NONE",  -- Sets output alignment to "NONE","C0", "C1" 
    INIT => '0',              -- Sets initial state of the Q output to '0' or '1'
    SRTYPE => "SYNC"          -- Specifies "SYNC" or "ASYNC" set/reset
  )
  port map (
    Q  => pix_clock_o,       -- 1-bit output data
    C0 => pix_clock_s,       -- 1-bit clock input
    C1 => pix_clock_n,       -- 1-bit clock input
    CE => '1',               -- 1-bit clock enable input
    D0 => '1',               -- 1-bit data input (associated with C0)
    D1 => '0',               -- 1-bit data input (associated with C1)
    R  => '0',               -- 1-bit reset input
    S  => '0'                -- 1-bit set input
  );
  pix_clock_n <= not(pix_clock_s);

  -- component instantiation
  vga_top_i: vga_top
  generic map(
    RES_TYPE             => RES_TYPE,
    H_RES                => H_RES,
    V_RES                => V_RES,
    MEM_ADDR_WIDTH       => MEM_ADDR_WIDTH,
    GRAPH_MEM_ADDR_WIDTH => GRAPH_MEM_ADDR_WIDTH,
    TEXT_MEM_DATA_WIDTH  => TEXT_MEM_DATA_WIDTH,
    GRAPH_MEM_DATA_WIDTH => GRAPH_MEM_DATA_WIDTH,
    MEM_SIZE             => MEM_SIZE
  )
  port map(
    clk_i              => clk_i,
    reset_n_i          => reset_n_i,
    --
    direct_mode_i      => direct_mode_i,
    dir_red_i          => dir_red,
    dir_green_i        => dir_green,
    dir_blue_i         => dir_blue,
    dir_pixel_column_o => dir_pixel_column,
    dir_pixel_row_o    => dir_pixel_row,
    -- cfg
    display_mode_i     => display_mode_i,  -- 01 - text mode, 10 - graphics mode, 11 - text & graphics
    -- text mode interface
    text_addr_i        => char_address,
    text_data_i        => char_value,
    text_we_i          => char_we,
    -- graphics mode interface
    graph_addr_i       => pixel_address,
    graph_data_i       => pixel_value,
    graph_we_i         => pixel_we,
    -- cfg
    font_size_i        => font_size,
    show_frame_i       => show_frame,
    foreground_color_i => foreground_color,
    background_color_i => background_color,
    frame_color_i      => frame_color,
    -- vga
    vga_hsync_o        => vga_hsync_o,
    vga_vsync_o        => vga_vsync_o,
    blank_o            => blank_o,
    pix_clock_o        => pix_clock_s,
    vga_rst_n_o        => vga_rst_n_s,
    psave_o            => psave_o,
    sync_o             => sync_o,
    red_o              => red_o,
    green_o            => green_o,
    blue_o             => blue_o     
  );
  
    -- na osnovu signala iz vga_top modula dir_pixel_column i dir_pixel_row realizovati logiku koja genereise
  --dir_red
  --dir_green
  --dir_blue
  process (dir_pixel_column, direct_mode_i, display_mode_i) begin
  
		if (dir_pixel_column >=0 and dir_pixel_column < 80) then
				dir_red <= "11111111"; 
				dir_green <= "11111111";
				dir_blue <= "11111111";
		elsif (dir_pixel_column >=80 and dir_pixel_column < 160) then
				dir_red <= "11111111"; 
				dir_green <= "11111111";
				dir_blue <= "00000000";
		elsif (dir_pixel_column >=160 and dir_pixel_column < 240) then
				dir_red <= x"87"; 
				dir_green <= x"cc";
				dir_blue <= x"eb";
		elsif (dir_pixel_column >=240 and dir_pixel_column < 320) then
				dir_red <= "00000000"; 
				dir_green <= "11111111";
				dir_blue <= "00000000";
				
		elsif (dir_pixel_column >=320 and dir_pixel_column < 400) then
				dir_red <= x"da"; 
				dir_green <= x"70";
				dir_blue <= x"d6";
		elsif (dir_pixel_column >=400 and dir_pixel_column < 480) then
				dir_red <= "11111111"; 
				dir_green <= "00000000";
				dir_blue <= "00000000";
		elsif (dir_pixel_column >=480 and dir_pixel_column < 560) then
				dir_red <= "00000000";
				dir_green <= "00000000";
				dir_blue <= "11111111";
		else 
				dir_red <= "00000000"; 
				dir_green <= "00000000";
				dir_blue <= "00000000";
		end if;
	
		
end process;
--drugi i treci zadatak

char_we <= '1';
process (pix_clock_s,reset_n_i) begin
	if (reset_n_i = '0') then
		char_address <= "00000000000000";
	elsif (rising_edge(pix_clock_s)) then
		char_address <= char_address + 1;
		if (char_address = 1199) then
			char_address <= "00000000000000";
		end if;			
	end if;
end process;




		
char_value <=  "000001" when char_address = ("00000000001001" + offset) else
					"001110" when char_address = ("00000000001010" + offset) else
					"000100" when char_address = ("00000000001011" + offset) else
					"010010" when char_address = ("00000000001100" + offset) else
					"000101" when char_address = ("00000000001101" + offset) else
					"001010" when char_address = ("00000000001110" + offset) else
					"100000";
					
process (pix_clock_s ,reset_n_i) begin
	if (reset_n_i  = '0') then
		sec_c <= "0000000000000000000000000";
		offset <= "00000000000000";
	elsif (rising_edge(pix_clock_s)) then
		sec_c <= sec_c + 1;
		offset <= offset;
		if (sec_c = 24999999) then
			sec_c <= "0000000000000000000000000";
			offset <= offset+1;
			if(("00000000001001" + offset) = 1199) then
				offset <= "00000000000000";
			end if;
		end if;			
	end if;
end process;	


  char_we <= '1';
  
 pixel_we <= '1';

  
  -- koristeci signale realizovati logiku koja pise po GRAPH_MEM
  --pixel_address
  --pixel_value
  --pixel_we
  
 
 process (pix_clock_s ,reset_n_i) begin
		if (reset_n_i  = '0') then
			pixel_address <= "00000000000000000000";
		elsif (rising_edge(pix_clock_s)) then
			pixel_address <= pixel_address +1;
			if (pixel_address = 9599) then
				pixel_address <= "00000000000000000000";
			end if;
		end if;
end process;

--pixel_value <= x"FFFFFFFF" when pixel_address = 128 else --prva vertikalna linija
--					x"FFFFFFFF" when pixel_address = 148 else
--					x"FFFFFFFF" when pixel_address = 168 else
--					x"FFFFFFFF" when pixel_address = 188 else
--					x"FFFFFFFF" when pixel_address = 208 else
--					x"FFFFFFFF" when pixel_address = 228 else
--					x"FFFFFFFF" when pixel_address = 248 else
--					x"FFFFFFFF" when pixel_address = 268 else
--					x"FFFFFFFF" when pixel_address = 288 else
--					x"FFFFFFFF" when pixel_address = 308 else
--					x"FFFFFFFF" when pixel_address = 328 else
--					x"FFFFFFFF" when pixel_address = 348 else
--					x"FFFFFFFF" when pixel_address = 368 else
--					x"FFFFFFFF" when pixel_address = 388 else
--					x"FFFFFFFF" when pixel_address = 408 else
--					x"FFFFFFFF" when pixel_address = 428 else
--					x"FFFFFFFF" when pixel_address = 448 else
--					x"FFFFFFFF" when pixel_address = 468 else
--					x"FFFFFFFF" when pixel_address = 488 else
--					x"FFFFFFFF" when pixel_address = 508 else
--					x"FFFFFFFF" when pixel_address = 528 else
--					x"FFFFFFFF" when pixel_address = 548 else
--					x"FFFFFFFF" when pixel_address = 568 else
--					x"FFFFFFFF" when pixel_address = 588 else
--					x"FFFFFFFF" when pixel_address = 608 else
--					x"FFFFFFFF" when pixel_address = 628 else
--					x"FFFFFFFF" when pixel_address = 648 else
--					x"FFFFFFFF" when pixel_address = 668 else
--					x"FFFFFFFF" when pixel_address = 688 else
--					x"FFFFFFFF" when pixel_address = 708 else
--					x"FFFFFFFF" when pixel_address = 728 else
--					x"FFFFFFFF" when pixel_address = 748 else
--					x"00000000";


--pixel_value <= x"FFFFFFFF" when pixel_address = 120 + offset1 else --prva vertikalna linija
--					x"FFFFFFFF" when pixel_address = 140 + offset1 else
--					x"FFFFFFFF" when pixel_address = 160 + offset1 else
--					x"FFFFFFFF" when pixel_address = 180 + offset1 else
--					x"FFFFFFFF" when pixel_address = 200 + offset1 else
--					x"FFFFFFFF" when pixel_address = 220 + offset1 else
--					x"FFFFFFFF" when pixel_address = 240 + offset1 else
--					x"FFFFFFFF" when pixel_address = 260 + offset1 else
--					x"FFFFFFFF" when pixel_address = 280 + offset1 else
--					x"FFFFFFFF" when pixel_address = 300 + offset1 else
--					x"FFFFFFFF" when pixel_address = 320 + offset1 else
--					x"FFFFFFFF" when pixel_address = 340 + offset1 else
--					x"FFFFFFFF" when pixel_address = 360 + offset1 else
--					x"FFFFFFFF" when pixel_address = 380 + offset1 else
--					x"FFFFFFFF" when pixel_address = 400 + offset1 else
--					x"FFFFFFFF" when pixel_address = 420 + offset1 else
--					x"FFFFFFFF" when pixel_address = 440 + offset1 else
--					x"FFFFFFFF" when pixel_address = 460 + offset1 else
--					x"FFFFFFFF" when pixel_address = 480 + offset1 else
--					x"FFFFFFFF" when pixel_address = 500 + offset1 else
--					x"FFFFFFFF" when pixel_address = 520 + offset1 else
--					x"FFFFFFFF" when pixel_address = 540 + offset1 else
--					x"FFFFFFFF" when pixel_address = 560 + offset1 else
--					x"FFFFFFFF" when pixel_address = 580 + offset1 else
--					x"FFFFFFFF" when pixel_address = 600 + offset1 else
--					x"FFFFFFFF" when pixel_address = 620 + offset1 else
--					x"FFFFFFFF" when pixel_address = 640 + offset1 else
--					x"FFFFFFFF" when pixel_address = 660 + offset1 else
--					x"FFFFFFFF" when pixel_address = 680 + offset1 else
--					x"FFFFFFFF" when pixel_address = 700 + offset1 else
--					x"FFFFFFFF" when pixel_address = 720 + offset1 else
--					x"FFFFFFFF" when pixel_address = 740 + offset1 else
--					x"00000000";
--					
--process (pix_clock_s ,reset_n_i) begin
--	if (reset_n_i  = '0') then
--		sec_c <= "0000000000000000000000000";
--		offset1 <= "00000000000000000000";
--	elsif (rising_edge(pix_clock_s)) then
--		sec_c <= sec_c + 1;
--		offset1 <= offset1;
--		if (sec_c = 24999999) then
--			sec_c <= "0000000000000000000000000";
--			offset1 <= offset1+1;
--			if(offset1 = 20) then
--				offset1 <= "00000000000000000000";
--			end if;
--		end if;			
--	end if;
--end process;		


pixel_value <= x"FFFFFFFF" when pixel_address = 120 + offset1 else 
					x"FFFFFFFF" when pixel_address = 140 + offset1 else
					x"FFFFFFFF" when pixel_address = 160 + offset1 else
					x"FFFFFFFF" when pixel_address = 180 + offset1 else
					x"FFFFFFFF" when pixel_address = 200 + offset1 else
					x"FFFFFFFF" when pixel_address = 220 + offset1 else
					x"FFFFFFFF" when pixel_address = 240 + offset1 else
					x"FFFFFFFF" when pixel_address = 260 + offset1 else
					x"FFFFFFFF" when pixel_address = 280 + offset1 else
					x"FFFFFFFF" when pixel_address = 300 + offset1 else
					x"FFFFFFFF" when pixel_address = 320 + offset1 else
					x"FFFFFFFF" when pixel_address = 340 + offset1 else
					x"FFFFFFFF" when pixel_address = 360 + offset1 else
					x"FFFFFFFF" when pixel_address = 380 + offset1 else
					x"FFFFFFFF" when pixel_address = 400 + offset1 else
					x"FFFFFFFF" when pixel_address = 420 + offset1 else
					x"FFFFFFFF" when pixel_address = 440 + offset1 else
					x"FFFFFFFF" when pixel_address = 460 + offset1 else
					x"FFFFFFFF" when pixel_address = 480 + offset1 else
					x"FFFFFFFF" when pixel_address = 500 + offset1 else
					x"FFFFFFFF" when pixel_address = 520 + offset1 else
					x"FFFFFFFF" when pixel_address = 540 + offset1 else
					x"FFFFFFFF" when pixel_address = 560 + offset1 else
					x"FFFFFFFF" when pixel_address = 580 + offset1 else
					x"FFFFFFFF" when pixel_address = 600 + offset1 else
					x"FFFFFFFF" when pixel_address = 620 + offset1 else
					x"FFFFFFFF" when pixel_address = 640 + offset1 else
					x"FFFFFFFF" when pixel_address = 660 + offset1 else
					x"FFFFFFFF" when pixel_address = 680 + offset1 else
					x"FFFFFFFF" when pixel_address = 700 + offset1 else
					x"FFFFFFFF" when pixel_address = 720 + offset1 else
					x"FFFFFFFF" when pixel_address = 740 + offset1 else
					x"00000000";
					
process (pix_clock_s ,reset_n_i) begin
	if (reset_n_i  = '0') then
		sec_c1 <= "0000000000000000000000000";
		offset1 <= "00000000000000000000";
	elsif (rising_edge(pix_clock_s)) then
		sec_c1 <= sec_c1 + 1;
		offset1 <= offset1;
		if (sec_c1 = 5000000) then
			sec_c1 <= "0000000000000000000000000";
			offset1 <= offset1+1;
			if(offset1 = 9599) then
				offset1 <= "00000000000000000000";
			end if;
		end if;			
	end if;
end process;		
					
					
					
		
  
  
end rtl;