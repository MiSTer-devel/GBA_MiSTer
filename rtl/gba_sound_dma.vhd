library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;

use work.pRegmap_gba.all;
use work.pProc_bus_gba.all;
use work.pReg_gba_sound.all;

use work.pReg_savestates.all;

entity gba_sound_dma is
   generic
   (
      REG_FIFO                : regmap_type;
      REG_SAVESTATE_DMASOUND  : regmap_type
   );
   port 
   (
      clk100              : in    std_logic;  
      reset               : in    std_logic;  
      
      loading_savestate   : in    std_logic;  
      savestate_bus       : inout proc_bus_gb_type;
      
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
      
      new_sample_out      : out   std_logic;
      
      debug_fifocount     : out   integer
   );
end entity;

architecture arch of gba_sound_dma is

   signal FIFO_REGISTER         : std_logic_vector(REG_FIFO.upper downto REG_FIFO.lower) := (others => '0');
   signal FIFO_REGISTER_written : std_logic; 
   signal FIFO_WRITE_ENABLES    : std_logic_vector(3 downto 0) := (others => '0');    
   
   signal any_on             : std_logic;
   signal new_sample_request : std_logic := '0';
   signal fifo_valid         : std_logic := '0';
   
   signal fifo_cnt   : integer range 0 to 7 := 0;
   signal fifo_reset : std_logic := '0';
   
   signal fifo_Din   : std_logic_vector(31 downto 0) := (others => '0');
   signal fifo_Wr    : std_logic := '0';
   signal fifo_Full  : std_logic;
   
   signal fifo_Dout  : std_logic_vector(31 downto 0);
   signal fifo_Rd    : std_logic := '0';
   signal fifo_Empty : std_logic;
   
   signal afterfifo_cnt  : integer range 0 to 3 := 0;
   signal afterfifo_data : std_logic_vector(31 downto 0) := (others => '0');
   
   signal sound_raw  : std_logic_vector(7 downto 0) := (others => '0');
   signal sound_out  : signed(15 downto 0) := (others => '0');

   -- savestate
   signal SAVESTATE_DMASOUND       : std_logic_vector(4 downto 0);
   signal SAVESTATE_DMASOUND_back  : std_logic_vector(4 downto 0);
   
   signal loading_fifo             : std_logic := '0';
   
begin 



   iFIFO_REGISTER : entity work.eProcReg_gba generic map (REG_FIFO) port map  (clk100, gb_bus, x"00000000", FIFO_REGISTER, FIFO_REGISTER_written);  
  
   any_on   <= Enable_LEFT or Enable_RIGHT;
   sound_on <= any_on;
   
   debug_fifocount <= fifo_cnt;
   
   sound_out_left  <= sound_out when Enable_LEFT  = '1' else (others => '0');
   sound_out_right <= sound_out when Enable_RIGHT = '1' else (others => '0');
   
   new_sample_out  <= new_sample_request;
   
   iSyncFifo : entity MEM.SyncFifo
   generic map
   (
      SIZE             => 8,
      DATAWIDTH        => 32,
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
   
   -- save state
   iSAVESTATE_DMASOUND : entity work.eProcReg_gba generic map (REG_SAVESTATE_DMASOUND) port map (clk100, savestate_bus, SAVESTATE_DMASOUND_back, SAVESTATE_DMASOUND);

   SAVESTATE_DMASOUND_back(2 downto 0) <= std_logic_vector(to_unsigned(fifo_cnt, 3));
   SAVESTATE_DMASOUND_back(4 downto 3) <= std_logic_vector(to_unsigned(afterfifo_cnt, 2));

   process (clk100)
   begin
      if rising_edge(clk100) then
         
         dma_req <= '0';
         
         fifo_reset <= '0';
         fifo_Wr    <= '0';
         fifo_Rd    <= '0';
         
         if (reset = '1') then
         
            sound_raw      <= (others => '0');
            sound_out      <= (others => '0');
            afterfifo_data <= (others => '0');
            
            afterfifo_cnt <= to_integer(unsigned(SAVESTATE_DMASOUND(4 downto 3)));
            
            fifo_reset    <= '1';
            fifo_cnt      <= 0;
            loading_fifo  <= '1';
         
         elsif (loading_fifo = '1') then
         
            if (fifo_cnt < to_integer(unsigned(SAVESTATE_DMASOUND(2 downto 0)))) then
               fifo_Wr  <= '1';
               fifo_Din <= (others => '0');
               fifo_cnt <= fifo_cnt + 1;
            else
               loading_fifo <= '0';
            end if;
         
         else
         
            if (fifo_Rd = '0' and fifo_valid = '0') then -- don't update when new data is read
               case (afterfifo_cnt) is
                  when 0 => sound_raw <= afterfifo_data(7 downto 0);
                  when 1 => sound_raw <= afterfifo_data(15 downto 8);
                  when 2 => sound_raw <= afterfifo_data(23 downto 16);
                  when 3 => sound_raw <= afterfifo_data(31 downto 24);
                  when others => null;
               end case;
            end if;
         
            if (volume_high = '1') then
               sound_out <= resize(signed(sound_raw) * 4, sound_out'length);
            else
               sound_out <= resize(signed(sound_raw) * 2, sound_out'length);
            end if;
         
            fifo_valid <= fifo_Rd;
            if (fifo_valid = '1') then
               afterfifo_data <= fifo_Dout;
            end if;
            
            FIFO_WRITE_ENABLES <= gb_bus.bEna;
            
            if (settings_new = '1' and Reset_FIFO = '1' and loading_savestate = '0') then
               fifo_reset    <= '1';
               fifo_cnt      <= 0;
               afterfifo_cnt <= 0;
            end if;
            
            -- keep new request if fifo is not idling to make sure the sample counter works correct
            if (any_on = '1' and ((timer0_tick = '1' and Timer_Select = '0') or (timer1_tick = '1' and Timer_Select = '1'))) then 
               new_sample_request <= '1';
            end if;
            
            if (FIFO_REGISTER_written = '1' and loading_savestate = '0') then
            
               if (fifo_Full = '0' and fifo_cnt < 7) then -- real hardware does also clear fifo when writing 8th dword(can only happen when writing without DMA)
                  fifo_cnt <= fifo_cnt + 1;
                  fifo_Wr  <= '1';
               end if;
               
               if (FIFO_WRITE_ENABLES(0) = '1') then fifo_Din( 7 downto  0) <= FIFO_REGISTER( 7 downto  0); end if;
               if (FIFO_WRITE_ENABLES(1) = '1') then fifo_Din(15 downto  8) <= FIFO_REGISTER(15 downto  8); end if;
               if (FIFO_WRITE_ENABLES(2) = '1') then fifo_Din(23 downto 16) <= FIFO_REGISTER(23 downto 16); end if;
               if (FIFO_WRITE_ENABLES(3) = '1') then fifo_Din(31 downto 24) <= FIFO_REGISTER(31 downto 24); end if;
               
            elsif (new_sample_request = '1') then -- get sample from fifo
               
               new_sample_request <= '0'; 
               
               if (fifo_cnt <= 3) then 
                  dma_req <= '1';
               end if; 
               
               if (afterfifo_cnt < 3) then
                  afterfifo_cnt <= afterfifo_cnt + 1;
               elsif (fifo_Empty = '0') then
                  afterfifo_cnt <= 0;
                  if (fifo_cnt > 0) then 
                     fifo_cnt <= fifo_cnt - 1;
                     fifo_Rd  <= '1';
                  end if;
               end if;
               
            end if;  
            
         end if;
      
      end if;
   end process;
  

end architecture;





