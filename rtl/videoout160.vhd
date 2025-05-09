library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

entity videoout160 is
   port 
   (
      clk1x                   : in  std_logic;
      clk3x                   : in  std_logic;
      
      blend                   : in  std_logic;
      borderOn                : in  std_logic;
      videoHshift             : in  signed(3 downto 0);      
      videoVshift             : in  signed(2 downto 0);   
      
      pixel_x                 : in  integer range 0 to 239;
      pixel_y                 : in  integer range 0 to 159;  
      pixel_we                : in  std_logic;
      vblank_trigger          : in  std_logic;

      nextFrame_out           : out std_logic_vector(1 downto 0);
      
      inPause                 : in  std_logic;
      requestPause            : out std_logic := '0';
      allowUnpause            : out std_logic := '0';

      ddr3_request            : out std_logic := '0';
      ddr3_address            : out unsigned(27 downto 0):= (others => '0');        
      ddr3_burstcnt           : out unsigned(9 downto 0):= (others => '0');        
      ddr3_ready              : in  std_logic;
      ddr3_done               : in  std_logic;
      ddr3_data               : in  std_logic_vector(63 downto 0):= (others => '0');      
      
      videoout_hsync          : out std_logic := '0';
      videoout_vsync          : out std_logic := '0';
      videoout_hblank         : out std_logic := '0';
      videoout_vblank         : out std_logic := '0';
      videoout_ce             : out std_logic;
      videoout_interlace      : out std_logic;
      videoout_r              : out unsigned(7 downto 0);
      videoout_g              : out unsigned(7 downto 0);
      videoout_b              : out unsigned(7 downto 0)
   );
end entity;

architecture arch of videoout160 is
   
   -- timing
   signal div              : unsigned(2 downto 0) := (others => '0');
   signal x                : unsigned(8 downto 0) := (others => '0');
   signal y                : unsigned(8 downto 0) := (others => '0');
   
   signal lineInNew        : std_logic := '0';
   signal lineInNew_1      : std_logic := '0';
   signal vpos             : unsigned(7 downto 0) := (others => '0');
   
   type tPauseState is
   (
      IDLE,
      WAIT_PAUSING,
      WAIT_LINES
   );
   signal pauseState       : tPauseState := IDLE;
   signal vsyncwaitcnt     : unsigned(8 downto 0) := (others => '0');
   
   -- output    
   signal lineWriteAddr    : unsigned(6 downto 0) := (others => '0');
   signal lineReadAddr     : unsigned(8 downto 0) := (others => '0');
   signal read_data        : std_logic_vector(15 downto 0);  
   signal read_data2       : std_logic_vector(15 downto 0);  
   signal secondFrame      : std_logic := '0';
   signal borderReadOn     : std_logic := '0';
   
   signal blineWriteAddr   : unsigned(8 downto 0) := (others => '0');
   signal blineReadAddr    : unsigned(9 downto 0) := (others => '0');
   signal bread_data       : std_logic_vector(31 downto 0);   
   
   signal nextFrame        : unsigned(1 downto 0) := (others => '0');
   signal currFrame        : unsigned(1 downto 0) := (others => '0');
   signal prevFrame        : unsigned(1 downto 0) := (others => '0');
   
   signal pixelData_R      : std_logic_vector(7 downto 0);
   signal pixelData_G      : std_logic_vector(7 downto 0);
   signal pixelData_B      : std_logic_vector(7 downto 0);
   
   signal pixelData_Add_R  : std_logic_vector(5 downto 0);
   signal pixelData_Add_G  : std_logic_vector(5 downto 0);
   signal pixelData_Add_B  : std_logic_vector(5 downto 0);
   
begin 
   
   ilineram: entity mem.dpram_dif
   generic map 
   ( 
      addr_width_a  => 7,
      data_width_a  => 64,
      addr_width_b  => 9,
      data_width_b  => 16
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => std_logic_vector(lineWriteAddr),
      data_a      => ddr3_data,
      wren_a      => ddr3_ready and (not secondFrame) and (not borderReadOn),
      
      clock_b     => clk3x,
      address_b   => std_logic_vector(lineReadAddr),
      data_b      => 16x"0",
      wren_b      => '0',
      q_b         => read_data
   );  

   ilineram2: entity mem.dpram_dif
   generic map 
   ( 
      addr_width_a  => 7,
      data_width_a  => 64,
      addr_width_b  => 9,
      data_width_b  => 16
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => std_logic_vector(lineWriteAddr),
      data_a      => ddr3_data,
      wren_a      => ddr3_ready and secondFrame and (not borderReadOn),
      
      clock_b     => clk3x,
      address_b   => std_logic_vector(lineReadAddr),
      data_b      => 16x"0",
      wren_b      => '0',
      q_b         => read_data2
   );   
   
   iborderlineram: entity mem.dpram_dif
   generic map 
   ( 
      addr_width_a  => 9,
      data_width_a  => 64,
      addr_width_b  => 10,
      data_width_b  => 32
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => std_logic_vector(blineWriteAddr),
      data_a      => ddr3_data,
      wren_a      => ddr3_ready and borderReadOn,
      
      clock_b     => clk3x,
      address_b   => std_logic_vector(blineReadAddr),
      data_b      => 32x"0",
      wren_b      => '0',
      q_b         => bread_data
   );   
      
   nextFrame_out <= std_logic_vector(nextFrame);
   
   videoout_interlace <= '0';
   
   pixelData_Add_R <= std_logic_vector(unsigned('0' & read_data(14 downto 10)) + unsigned('0' & read_data2(14 downto 10)));
   pixelData_Add_G <= std_logic_vector(unsigned('0' & read_data(9  downto  5)) + unsigned('0' & read_data2(9  downto  5)));
   pixelData_Add_B <= std_logic_vector(unsigned('0' & read_data(4  downto  0)) + unsigned('0' & read_data2(4  downto  0)));
   
   pixelData_R <= pixelData_Add_R & pixelData_Add_R(5 downto 4) when (blend = '1') else read_data(14 downto 10) & read_data(14 downto 12);
   pixelData_G <= pixelData_Add_G & pixelData_Add_G(5 downto 4) when (blend = '1') else read_data(9  downto  5) & read_data(9  downto  7);
   pixelData_B <= pixelData_Add_B & pixelData_Add_B(5 downto 4) when (blend = '1') else read_data(4  downto  0) & read_data(4  downto  2);

   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         ddr3_request <= '0';
         
         if (ddr3_ready = '1') then
            lineWriteAddr  <= lineWriteAddr + 1;
            blineWriteAddr <= blineWriteAddr + 1;
         end if;
         
         lineInNew_1 <= lineInNew;
         
         
         if (lineInNew /= lineInNew_1 and borderOn = '1') then
            borderReadOn   <= '1';
            ddr3_request   <= '1';
            ddr3_address   <= x"D" & to_unsigned(1280 * to_integer(y - 21), 24);
            ddr3_burstcnt <= 10x"A0"; -- 160 * 64bit = 320 * 32 bit
            blineWriteAddr <= vpos(0) & 8x"0";
         elsif (y >= 61 and y < 62+160) then
            if ((lineInNew /= lineInNew_1 and borderOn = '0') or (ddr3_done = '1' and borderReadOn = '1')) then
               borderReadOn <= '0';
               ddr3_request  <= '1';
               ddr3_address  <= '1' & "00000000" & currFrame & vpos & 6x"0" & "000";
               ddr3_burstcnt <= 10x"3C"; -- 60 * 64bit = 240 * 16 bit
               lineWriteAddr <= vpos(0) & 6x"0";
               secondFrame   <= '0';
            elsif (ddr3_done = '1' and secondFrame = '0' and blend = '1' ) then
               secondFrame                <= '1';
               ddr3_request               <= '1';
               ddr3_address(18 downto 17) <= prevFrame;
               lineWriteAddr(5 downto 0)  <= (others => '0');
            end if;
         end if;
         
         if (pixel_we = '1' and pixel_x = 239 and pixel_y = 159) then
            nextFrame <= nextFrame + 1;
            currFrame <= nextFrame;
            prevFrame <= currFrame;
         end if;

      end if;
   end process;

   process (clk3x)
   begin
      if rising_edge(clk3x) then       
 
         videoout_ce <= '0';
         
         div <= div + 1;
        
         if(div = 0) then
            videoout_ce <= '1';
         
            if (x < 240 and y >= 62 and y < 222) then 
               videoout_r      <= unsigned(pixelData_R);
               videoout_g      <= unsigned(pixelData_G);
               videoout_b      <= unsigned(pixelData_B);
            else             
               videoout_r      <= unsigned(bread_data( 7 downto  0));
               videoout_g      <= unsigned(bread_data(15 downto  8));
               videoout_b      <= unsigned(bread_data(23 downto 16));
            end if;
         
            if (borderOn = '1') then 
               if (x = 280)             then videoout_hblank <= '1'; end if;
               if (x = 359)             then videoout_hblank <= '0'; end if; 
               if (y  = 21 and x = 359) then videoout_vblank <= '0'; end if;
               if (y >= 62+199)         then videoout_vblank <= '1'; end if;
            else
               if (x = 240)     then videoout_hblank <= '1'; end if;
               if (x =   0)     then videoout_hblank <= '0'; end if;
               if (y  = 62)     then videoout_vblank <= '0'; end if;
               if (y >= 62+160) then videoout_vblank <= '1'; end if;
            end if;
         
            if(x = 293 + to_integer(videoHshift)) then
               videoout_hsync <= '1';
               if (videoVshift < -1) then
                  if (y = 265 + to_integer(videoVshift)) then videoout_vsync <= '1'; end if;
               else
                  if (y = 1 + to_integer(videoVshift)) then videoout_vsync <= '1'; end if;
               end if;
               if (y = 4 + to_integer(videoVshift)) then videoout_vsync <= '0'; end if;
            end if;
         
            if(x = 293+32+to_integer(videoHshift)) then videoout_hsync <= '0'; end if;
            
            if (x = 0) then
               if (y >= 21 and y < 62+199) then
                  lineInNew <= not lineInNew;
                  vpos      <= resize(y - 61, vpos'length);
               end if;
            end if;
         end if;
         
         if(videoout_ce = '1') then
            if(videoout_hblank = '1') then
               lineReadAddr  <= vpos(0) & x"00";
               blineReadAddr <= vpos(0) & 9x"00";
            else
               blineReadAddr <= blineReadAddr + 1;
               if (x < 240) then
                  lineReadAddr <= lineReadAddr + 1;
               end if;
            end if;
      
            x <= x + 1;
            if(x = 398) then
               x <= (others => '0');
               if (y < 511) then y <= y + 1; end if;
            end if;
         end if;

         if (x = 0 and y = 264 and div = 5) then
            x  <= (others => '0');
            y  <= (others => '0');
         end if;
         
         case (pauseState) is
            when IDLE =>
               allowUnpause <= '1';
               if (pixel_we = '1' and pixel_x = 0 and pixel_y = 150) then 
                  if (inPause = '0' and y < 256) then
                     pauseState   <= WAIT_PAUSING;
                     vsyncwaitcnt <= 260 - y;
                     requestPause <= '1';
                  end if;
               end if;
            
            when WAIT_PAUSING =>
               if (inPause = '1') then
                  pauseState   <= WAIT_LINES;
                  requestPause <= '0';
                  allowUnpause <= '0';
               end if;
               
            when WAIT_LINES =>
               if (vsyncwaitcnt = 0) then
                  pauseState <= IDLE;
               else
                  if (x = 0 and div = 0) then
                     vsyncwaitcnt <= vsyncwaitcnt - 1;
                  end if;
               end if;
         
         end case;
         
         
      end if;
   end process;

end architecture;





