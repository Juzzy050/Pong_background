library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity pong_graph_st is
	port(
		video_on: in std_logic;
		pixel_x,pixel_y: in std_logic_vector(9 downto 0);
		graph_rgb: out std_logic_vector(2 downto 0)
		);
	
end pong_graph_st;

architecture sq_ball_arch of pong_graph_st is
	-- x, y coordinates (0,0) to (639,479);
	signal pix_x, pix_y: unsigned (9 downto 0);
	constant MAX_X: integer := 640;
	constant MAX_Y: integer := 480;
	---------------------------------------------
	--vertical stripe as wall 
	---------------------------------------------
	--wall left, right boundary 
	constant WALL_X_L: integer:=32;
	constant WALL_X_R: integer:=35;
	--bar left, right boundary
	constant BAR_X_L: integer:= 600;
	constant BAR_X_R: integer:= 603;
	-- bar top, bottom boundary
	constant BAR_Y_SIZE: integer:= 72;
	constant BAR_Y_T: integer:= MAX_Y/2-BAR_Y_SIZE/2;  --204
	constant BAR_Y_B: integer:= BAR_Y_T+BAR_Y_SIZE-1;
	--------------------------------------------------------------
	--SQUARE BALL
	-----------------------------------------------
	constant BALL_SIZE: integer:=8;
	-- ball left, right boundary
	constant BALL_X_L: integer:= 580;
	constant BALL_X_R: integer:= BALL_X_L+BALL_SIZE-1;
	-- ball top, bottom boundary
	constant BALL_Y_T: integer:= 238;
	constant BALL_Y_B: integer:= BALL_Y_T+BALL_SIZE-1;
	--------------------------------------------------------
	--OBJECT OUTPUT SIGNALS
	--------------------------------------------------------
	signal wall_on, bar_on, sq_ball_on: std_logic;
	signal wall_rgb, bar_rgb, ball_rgb:std_logic_vector(2 downto 0);

begin
	pix_x <= unsigned(pixel_x);
	pix_y <= unsigned(pixel_y);
	-------------------------------------
	--(wall) left vertical stripe
	-----------------------------------
	-- pixel within wall 
	wall_on <=
		'1' when (WALL_X_L <= pix_x) and (pix_x <= WALL_X_R) else 
		'0';
	-- wall rgb output
	wall_rgb <= "001"; --blue
	------------------------------------------
	--right vertical bar
	-----------------------------------
	--pixel within bar 
	bar_on <= 
		'1' when (BAR_X_L <= pix_x) and (pix_x <= BAR_X_R) and 
					(BAR_Y_T <= pix_y) and (pix_y <= BAR_Y_B) else 
		'0';
		--bar rgb output
	bar_rgb <= "010"; -- green
	----------------------------------------
	-- square ball 
	-------------------------------------
	-- pixel within squared ball 
	sq_ball_on <= 
		'1' when (BALL_X_L <= pix_x) and (pix_x <= BALL_X_R) and
					(BALL_Y_T <= pix_y) and (pix_y <= BALL_Y_B) else 
		'0';
	ball_rgb <= "100"; -- red 
	---------------------------------------------------
	-- rgb multiplexing circuit 
	--------------------------------------------------------
	process (video_on, wall_on, bar_on, sq_ball_on, 
				wall_rgb, bar_rgb, ball_rgb)
	begin 
		if video_on = '0' then 
			graph_rgb <= "000"; -- blank 
		else 
			if wall_on='1' then 
				graph_rgb <= wall_rgb;
			elsif bar_on = '1' then 
				graph_rgb <= bar_rgb;
			elsif sq_ball_on = '1' then
				graph_rgb <= ball_rgb;
			else 
				graph_rgb <= "110"; -- yellow background 
			end if;
		end if;
	end process;
end sq_ball_arch;

----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity pong_top_st is
	port (
		clk, reset: in std_logic;
		hsync, vsync: out std_logic;
		rgb: out std_logic_vector(2 downto 0)
		);

end pong_top_st;

architecture arch of pong_top_st is
	signal pixel_x, pixel_y: std_logic_vector( 9 downto 0);
	signal video_on, pixel_tick: std_logic;
	signal rgb_reg, rgb_next: std_logic_vector(2 downto 0);

begin
	-- instantiate VGA sync 
	vga_sync_unit: entity work.vga_sync
		port map(clk=>clk, reset=>reset,
					video_on=>video_on, p_tick=>pixel_tick,
					hsync=>hsync, vsync=>vsync,
					pixel_x=>pixel_x, pixel_y=>pixel_y);
	-- instantiate graphic generator 
	pong_grf_st_unit: entity work.pong_graph_st(sq_ball_arch)
		port map (video_on=>video_on,
					 pixel_x=>pixel_x, pixel_y=>pixel_y,
					 graph_rgb=>rgb_next);
	-- rgb buffer 
	process (clk)
	begin 
		if (clk'event and clk='1') then 
			if (pixel_tick = '1') then
				rgb_reg <= rgb_next;
			end if;
		end if;
	end process;
	rgb <= rgb_reg;

end arch;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity vga_sync is
	port(
		clk, reset: in std_logic;
		hsync, vsync : out std_logic;
		video_on, p_tick : out std_logic;
		pixel_x, pixel_y : out std_logic_vector (9 downto 0)
		);

end vga_sync;

architecture arch of vga_sync is
	-- VGA 640-by-480 sync parameters
	constant HD: integer := 640; -- horizontal display area 
	constant HF: integer := 16; -- h. front porch  
	constant HB: integer := 48; -- h. back porch  
	constant HR: integer := 96; -- h. retrace  
	constant VD: integer := 480; -- vertical display area 
	constant VF: integer := 10; -- v. front porch 
	constant VB: integer := 33; -- v. back porch 
	constant VR: integer := 2; --  v. retrace 
	
	-- mod 2 counter 
	signal mod2_reg, mod2_next: std_logic;
	
	--sync counters 
	signal v_count_reg, v_count_next: unsigned(9 downto 0);
	signal h_count_reg, h_count_next: unsigned(9 downto 0);
	
	--output buffer
	signal v_sync_reg, h_sync_reg: std_logic;
	signal v_sync_next, h_sync_next: std_logic;
	
	--status signal
	signal h_end, v_end, pixel_tick: std_logic;
	

begin
	-- registers
	process (clk, reset)
	begin 
		if reset = '1' then 
			mod2_reg <= '0';
			v_count_reg <= (others => '0');
			h_count_reg <= (others => '0');
			v_sync_reg <= '0';
			h_sync_reg <= '0';
		elsif (clk'event and clk = '1') then 
			mod2_reg <= mod2_next;
			v_count_reg <= v_count_next;
			h_count_reg <= h_count_next;			
			v_sync_reg <= v_sync_next;
			h_sync_reg <= h_sync_next;
		end if;
	end process;
	
	--mod-2 circuit to generate 25MHz enable tick
	mod2_next <= not mod2_reg;
	-- 25MHz pixel tick
	pixel_tick <= '1' when mod2_reg='1' else '0';
	
	-- status 
	h_end <= -- end of horizontal counter 
		'1' when h_count_reg = (HD + HF + HB + HR -1) else -- 799
		'0';
	v_end <= -- end of verical counter 
		'1' when v_count_reg = (VD + VF + VB + VR -1) else -- 524
		'0';	
		
	-- mod -- horizontal sync count 
	process (h_count_reg, h_end, pixel_tick)
	begin 
		if pixel_tick = '1' then -- 25MHz tick
			if h_end = '1' then
				h_count_next <= (others => '0');
			else 
				h_count_next <= h_count_reg + 1;
			end if;
		else 
			h_count_next <= h_count_reg;
		end if; 
	end process;
	
	-- mod -525 veritcal sync counter 
	process (v_count_reg, h_end, v_end, pixel_tick)
	begin
		if pixel_tick = '1' and h_end = '1' then 
			if (v_end = '1') then 
			v_count_next <= (others => '0');
			else 
				v_count_next <= v_count_reg + 1;
			end if;
		else 
			v_count_next <= v_count_reg;
