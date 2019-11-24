library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;

use work.pRegmap_gba.all;
use work.pProc_bus_gba.all;
use work.pReg_gba_sound.all;

entity gba_sound_dma is
   generic
   (
      REG_FIFO            : regmap_type
   );
   port 
   (
      clk100              : in    std_logic;  
      gb_on               : in    std_logic;  
      gb_bus              : inout proc_bus_gb_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z', "ZZ", "ZZZZ", 'Z');
      
      settings_new        : in    std_logic;
      Enable_RIGHT        : in    std_logic;
      Enable_LEFT         : in    std_logic;
      Timer_Select        : in    std_logic;
      Reset_FIFO          : in    std_logic;
      volume_high         : in    std_logic;
      
      timer0_tick         : in    std_logic;
      timer1_tick         : in    std_logic;
      dma_req             : out   std_logic := '0';
      
      sound_out_left      : out   signed(15 downto 0) := (others => '0');
      sound_out_right     : out   signed(15 downto 0) := (others => '0');
      sound_on            : out   std_logic := '0';
      
      debug_fifocount     : out   integer
   );
end entity;

architecture arch of gba_sound_dma is

   signal FIFO_REGISTER         : std_logic_vector(REG_FIFO.upper downto REG_FIFO.lower) := (others => '0');
   signal FIFO_REGISTER_written : std_logic; 
   signal FIFO_WRITE_ENABLES    : std_logic_vector(3 downto 0) := (others => '0');    
   
   signal any_on             : std_logic;
   signal new_sample_request : std_logic := '0';
   signal fillbytes          : integer range 0 to 4 := 0;
   signal write_data         : std_logic_vector(REG_FIFO.upper downto REG_FIFO.lower) := (others => '0');
   signal fifo_valid         : std_logic := '0';
   
   signal fifo_cnt   : integer range 0 to 63 := 0;
   signal fifo_reset : std_logic := '0';
   
   signal fifo_Din   : std_logic_vector(7 downto 0) := (others => '0');
   signal fifo_Wr    : std_logic := '0';
   signal fifo_Full  : std_logic;
   
   signal fifo_Dout  : std_logic_vector(7 downto 0);
   signal fifo_Rd    : std_logic := '0';
   signal fifo_Empty : std_logic;
   
   signal sound_out  : signed(15 downto 0) := (others => '0');

   
begin 

   iFIFO_REGISTER : entity work.eProcReg_gba generic map (REG_FIFO) port map  (clk100, gb_bus, x"00000000", FIFO_REGISTER, FIFO_REGISTER_written);  
  
   any_on   <= Enable_LEFT or Enable_RIGHT;
   sound_on <= any_on;
   
   debug_fifocount <= fifo_cnt;
   
   sound_out_left  <= sound_out when Enable_LEFT  = '1' else (others => '0');
   sound_out_right <= sound_out when Enable_RIGHT = '1' else (others => '0');
   
   iSyncFifo : entity MEM.SyncFifo
   generic map
   (
      SIZE             => 64,
      DATAWIDTH        => 8,
      NEARFULLDISTANCE => 0
   )
   port map
   ( 
      clk      => clk100,
      reset    => fifo_reset,
               
      Din      => fifo_Din,  
      Wr       => fifo_Wr,   
      Full     => fifo_Full, 
                  
      Dout     => fifo_Dout, 
      Rd       => fifo_Rd,   
      Empty    => fifo_Empty
   );
   
   process (clk100)
   begin
      if rising_edge(clk100) then
         
         dma_req <= '0';
         
         fifo_reset <= '0';
         fifo_Wr    <= '0';
         fifo_Rd    <= '0';
         
         if (gb_on = '0') then
         
            sound_out <= (others => '0');
         
         else
         
            fifo_valid <= fifo_Rd;
            if (fifo_valid = '1') then
               if (volume_high = '1') then
                  sound_out <= resize(signed(fifo_Dout) * 4, sound_out'length);
               else
                  sound_out <= resize(signed(fifo_Dout) * 2, sound_out'length);
               end if;
            end if;
            
            FIFO_WRITE_ENABLES <= gb_bus.bEna;
            
            if (settings_new = '1' and Reset_FIFO = '1') then
               fifo_reset <= '1';
               fifo_cnt   <= 0;
            end if;
            
            -- keep new request if fifo is not idling to make sure the sample counter works correct
            if (any_on = '1' and ((timer0_tick = '1' and Timer_Select = '0') or (timer1_tick = '1' and Timer_Select = '1'))) then 
               new_sample_request <= '1';
            end if;
            
            if (FIFO_REGISTER_written = '1') then
            
               if (FIFO_WRITE_ENABLES(2) = '1') then -- 32bit write
                  fillbytes  <= 4;
                  write_data <= FIFO_REGISTER;
               else -- 16bit write
                  fillbytes <= 2;
                  write_data(31 downto 16) <= FIFO_REGISTER(15 downto 0);
               end if;
               
            elsif (fillbytes > 0) then -- fill fifo
            
               fillbytes <= fillbytes - 1;
               if (fifo_Full = '0' and fifo_cnt < 63) then
                  fifo_cnt <= fifo_cnt + 1;
                  fifo_Wr  <= '1';
                  case (fillbytes) is
                     when 4 => fifo_Din <= write_data( 7 downto 0);
                     when 3 => fifo_Din <= write_data(15 downto 8);
                     when 2 => fifo_Din <= write_data(23 downto 16);
                     when 1 => fifo_Din <= write_data(31 downto 24);
                     when others => null;
                  end case;
               end if;
               
            elsif (new_sample_request = '1') then -- get sample from fifo
            
               new_sample_request <= '0'; 
               if (fifo_cnt > 0) then 
                  fifo_cnt <= fifo_cnt - 1;
                  if (fifo_Empty = '0') then
                     fifo_Rd  <= '1';
                  end if;
               end if;
               
               if ((fifo_cnt = 0) or ((fifo_cnt - 1) = 0) or ((fifo_cnt - 1) = 16)) then 
                  dma_req <= '1';
               end if; 
               
            end if;  
            
         end if;
      
      end if;
   end process;
  

end architecture;





