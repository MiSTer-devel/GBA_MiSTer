-----------------------------------------------------------------
--------------- DDR3Mux Package  --------------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pDDR3 is

   constant DDR3MUXCOUNT : integer := 3;
   
   constant DDR3MUX_VIDEOOUT : integer := 0;
   constant DDR3MUX_SS       : integer := 1;
   constant DDR3MUX_ROMCOPY  : integer := 2;
   
   type tDDDR3Single     is array(0 to DDR3MUXCOUNT - 1) of std_logic;
   type tDDDR3ReqAddr    is array(0 to DDR3MUXCOUNT - 1) of unsigned(27 downto 0);
   type tDDDR3Burstcount is array(0 to DDR3MUXCOUNT - 1) of unsigned(9 downto 0);
   type tDDDR3BwriteMask is array(0 to DDR3MUXCOUNT - 1) of std_logic_vector(7 downto 0);
   type tDDDR3BwriteData is array(0 to DDR3MUXCOUNT - 1) of std_logic_vector(63 downto 0);
  
end package;

-----------------------------------------------------------------
--------------- DDR3Mux module    -------------------------------
-----------------------------------------------------------------

-- 234...256 Mbyte = Savestates                 (E000000)
-- 218...220 Mbyte = Border(320x240x4)          (D000000)
-- 128...129 Mbyte = 4 Framebuffers(240x160x2)  (8000000)
-- 0.5..64.5 Mbyte = Game ROM                   (0080000)

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;
use work.pDDR3.all;

entity DDR3Mux is
   port 
   (
      clk1x            : in  std_logic;
      
      error            : out std_logic;
      error_fifo       : out std_logic;

      ddr3_BUSY        : in  std_logic;                    
      ddr3_DOUT        : in  std_logic_vector(63 downto 0);
      ddr3_DOUT_READY  : in  std_logic;
      ddr3_BURSTCNT    : out std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_ADDR        : out std_logic_vector(28 downto 0) := (others => '0');                       
      ddr3_DIN         : out std_logic_vector(63 downto 0) := (others => '0');
      ddr3_BE          : out std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_WE          : out std_logic := '0';
      ddr3_RD          : out std_logic := '0';
      
      rdram_request    : in  tDDDR3Single;
      rdram_rnw        : in  tDDDR3Single;    
      rdram_address    : in  tDDDR3ReqAddr;
      rdram_burstcount : in  tDDDR3Burstcount;  
      rdram_writeMask  : in  tDDDR3BwriteMask;  
      rdram_dataWrite  : in  tDDDR3BwriteData;
      rdram_granted    : out tDDDR3Single;
      rdram_done       : out tDDDR3Single;
      rdram_ready      : out tDDDR3Single;
      rdram_dataRead   : out std_logic_vector(63 downto 0);
      
      gpufifo_reset    : in  std_logic; 
      gpufifo_Din      : in  std_logic_vector(33 downto 0); -- 16bit data + 18 bit address
      gpufifo_Wr       : in  std_logic;  
      gpufifo_nearfull : out std_logic;  
      gpufifo_empty    : out std_logic
   );
end entity;

architecture arch of DDR3Mux is

   type tddr3State is
   (
      IDLE,
      WAITREAD,
      READAGAIN
   );
   signal ddr3State     : tddr3State := IDLE;
   
   signal readCount     : unsigned(7 downto 0);
   signal timeoutCount  : unsigned(12 downto 0);
   
   signal req_latched   : tDDDR3Single := (others => '0');
   signal lastIndex     : integer range 0 to DDR3MUXCOUNT - 1;
   signal remain        : unsigned(9 downto 0);
   signal lastReadReq   : std_logic;
   
   -- gpu fifo
   signal gpufifo_Dout     : std_logic_vector(33 downto 0);
   signal gpufifo_Rd       : std_logic := '0';      
   signal gpufifo_Next     : std_logic_vector(47 downto 0) := (others => '0');

begin 

   ddr3_ADDR(28 downto 25) <= "0011";
   
   process (all)
   begin
      rdram_ready <= (others => '0');
      if (ddr3_DOUT_READY = '1') then
         rdram_ready(lastIndex) <= '1';
      end if;
   end process;

   process (clk1x)
      variable activeRequest : std_logic;
      variable activeIndex   : integer range 0 to DDR3MUXCOUNT - 1;
   begin
      if rising_edge(clk1x) then
      
         error         <= '0';
         
         gpufifo_Rd    <= '0';
         
         rdram_granted <= (others => '0');
         rdram_done    <= (others => '0');
      
         if (ddr3_BUSY = '0') then
            ddr3_WE <= '0';
            ddr3_RD <= '0';
         end if;

         -- request handling
         activeRequest := '0';
         for i in 0 to DDR3MUXCOUNT - 1 loop
            if (rdram_request(i) = '1') then
               req_latched(i) <= '1';
               activeRequest := '1';
               activeIndex   := i;
            end if;
         end loop;
        
        for i in 0 to DDR3MUXCOUNT - 1 loop
            if (req_latched(i) = '1') then
               activeRequest := '1';
               activeIndex   := i;
            end if;
         end loop;

         -- main statemachine
         case (ddr3State) is
            when IDLE =>
               
               lastIndex    <= activeIndex;
               timeoutCount <= (others => '0');
            
               if (ddr3_BUSY = '0' or ddr3_WE = '0') then
               
                  if (activeRequest = '1') then
                  
                     req_latched(activeIndex) <= '0';
                     ddr3_DIN                 <= rdram_dataWrite(activeIndex);
                     ddr3_BE                  <= rdram_writeMask(activeIndex);
                     ddr3_ADDR(24 downto 0)   <= std_logic_vector(rdram_address(activeIndex)(27 downto 3));
                     
                     if (rdram_burstcount(activeIndex)(9 downto 8) = "00") then
                        ddr3_BURSTCNT  <= std_logic_vector(rdram_burstcount(activeIndex)(7 downto 0));
                        readCount      <= rdram_burstcount(activeIndex)(7 downto 0);
                        lastReadReq    <= '1';
                     else
                        ddr3_BURSTCNT  <= x"FF";
                        readCount      <= x"FF";
                        lastReadReq    <= '0';
                     end if;
                     
                     remain    <= rdram_burstcount(activeIndex) - 16#FF#;
   
                     if (rdram_rnw(activeIndex) = '1') then
                        ddr3State                     <= WAITREAD;
                        ddr3_RD                       <= '1';
                        rdram_granted(activeIndex)    <= '1'; 
                     else
                        ddr3_WE                       <= '1';
                        rdram_done(activeIndex)       <= '1'; 
                     end if;
                   
                  elsif (gpufifo_empty = '0' and gpufifo_Rd = '0') then
                  
                     if (gpufifo_Dout(17 downto 16) = "00") then gpufifo_Next(15 downto  0) <= gpufifo_Dout(15 downto 0); end if;     
                     if (gpufifo_Dout(17 downto 16) = "01") then gpufifo_Next(31 downto 16) <= gpufifo_Dout(15 downto 0); end if;     
                     if (gpufifo_Dout(17 downto 16) = "10") then gpufifo_Next(47 downto 32) <= gpufifo_Dout(15 downto 0); end if;     
                     if (gpufifo_Dout(17 downto 16) = "11") then 
                        ddr3_DIN <= gpufifo_Dout(15 downto 0) & gpufifo_Next; 
                        ddr3_WE <= '1'; 
                     end if;     
                  
                     gpufifo_Rd <= '1';
                     ddr3_BE    <= x"FF";       
                     ddr3_ADDR(24 downto 0) <= "100000000" & gpufifo_Dout(33 downto 18);
                     ddr3_BURSTCNT <= x"01";
                     
                  end if;
                  
               end if;
                  
            when WAITREAD =>
               timeoutCount <= timeoutCount + 1;
               if (timeoutCount(timeoutCount'high) = '1') then
                  error <= '1';
               end if;
               if (ddr3_DOUT_READY = '1') then
                  timeoutCount          <= (others => '0');
                  readCount             <= readCount - 1;
                  rdram_dataRead        <= ddr3_DOUT;
                  if (readCount = 1) then
                     if (lastReadReq = '1') then
                        ddr3State             <= IDLE;
                        rdram_done(lastIndex) <= '1';
                     else
                        ddr3State       <= READAGAIN; 
                     end if;
                  end if;
               end if;
               
            when READAGAIN =>
               ddr3_ADDR(20 downto 0)   <= std_logic_vector(unsigned(ddr3_ADDR(20 downto 0)) + 16#FF#);
                  
               if (remain(9 downto 8) = "00") then
                  ddr3_BURSTCNT  <= std_logic_vector(remain(7 downto 0));
                  readCount      <= remain(7 downto 0);
                  lastReadReq    <= '1';
               else
                  ddr3_BURSTCNT  <= x"FF";
                  readCount      <= x"FF";
                  lastReadReq    <= '0';
               end if;
               
               ddr3State <= WAITREAD;
               ddr3_RD   <= '1';
               remain    <= remain - 16#FF#;
         
         end case;

      end if;
   end process;
   
   
   iGPUFifo: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 512,
      DATAWIDTH        => 16 + 18, -- 16bit data + 18 bit address
      NEARFULLDISTANCE => 32
   )
   port map
   ( 
      clk      => clk1x,
      reset    => gpufifo_reset,  
      Din      => gpufifo_Din,     
      Wr       => gpufifo_Wr,
      Full     => error_fifo,    
      NearFull => gpufifo_nearfull,
      Dout     => gpufifo_Dout,    
      Rd       => gpufifo_Rd,      
      Empty    => gpufifo_empty   
   );   

end architecture;





