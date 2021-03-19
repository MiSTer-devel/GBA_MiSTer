library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   

entity gba_drawer_merge is
   port 
   (
      clk100               : in  std_logic;                     
        
      enable               : in  std_logic;
      hblank               : in  std_logic;
      xpos                 : in  integer range 0 to 239;
      ypos                 : in  integer range 0 to 159;
      
      in_WND0_on           : in  std_logic;
      in_WND1_on           : in  std_logic;
      in_WNDOBJ_on         : in  std_logic;
      
      in_WND0_X1           : in  unsigned(7 downto 0);
      in_WND0_X2           : in  unsigned(7 downto 0);
      in_WND0_Y1           : in  unsigned(7 downto 0);
      in_WND0_Y2           : in  unsigned(7 downto 0);
      in_WND1_X1           : in  unsigned(7 downto 0);
      in_WND1_X2           : in  unsigned(7 downto 0);
      in_WND1_Y1           : in  unsigned(7 downto 0);
      in_WND1_Y2           : in  unsigned(7 downto 0);
      
      in_enables_wnd0      : in  std_logic_vector(5 downto 0);
      in_enables_wnd1      : in  std_logic_vector(5 downto 0);
      in_enables_wndobj    : in  std_logic_vector(5 downto 0);
      in_enables_wndout    : in  std_logic_vector(5 downto 0);

      in_special_effect_in : in  unsigned(1 downto 0);
      in_effect_1st_bg0    : in  std_logic;
      in_effect_1st_bg1    : in  std_logic;
      in_effect_1st_bg2    : in  std_logic;
      in_effect_1st_bg3    : in  std_logic;
      in_effect_1st_obj    : in  std_logic;
      in_effect_1st_BD     : in  std_logic;
      in_effect_2nd_bg0    : in  std_logic;
      in_effect_2nd_bg1    : in  std_logic;
      in_effect_2nd_bg2    : in  std_logic;
      in_effect_2nd_bg3    : in  std_logic;
      in_effect_2nd_obj    : in  std_logic;
      in_effect_2nd_BD     : in  std_logic;
     
      in_Prio_BG0          : in  unsigned(1 downto 0);
      in_Prio_BG1          : in  unsigned(1 downto 0);
      in_Prio_BG2          : in  unsigned(1 downto 0);
      in_Prio_BG3          : in  unsigned(1 downto 0);
      
      in_EVA               : in  unsigned(4 downto 0);
      in_EVB               : in  unsigned(4 downto 0);
      in_BLDY              : in  unsigned(4 downto 0);
      
      in_ena_bg0           : in  std_logic;
      in_ena_bg1           : in  std_logic;
      in_ena_bg2           : in  std_logic;
      in_ena_bg3           : in  std_logic;
      in_ena_obj           : in  std_logic;
      
      pixeldata_bg0        : in  std_logic_vector(15 downto 0);
      pixeldata_bg1        : in  std_logic_vector(15 downto 0);
      pixeldata_bg2        : in  std_logic_vector(15 downto 0);
      pixeldata_bg3        : in  std_logic_vector(15 downto 0);
      pixeldata_obj        : in  std_logic_vector(18 downto 0);
      pixeldata_back       : in  std_logic_vector(15 downto 0);
      objwindow_in         : in  std_logic;
      
      pixeldata_out        : out std_logic_vector(15 downto 0) := (others => '0');
      pixel_x              : out integer range 0 to 239;
      pixel_y              : out integer range 0 to 159;
      pixel_we             : out std_logic
   );
end entity;

architecture arch of gba_drawer_merge is
    
   constant BG0 : integer := 0;
   constant BG1 : integer := 1;
   constant BG2 : integer := 2;
   constant BG3 : integer := 3;
   constant OBJ : integer := 4;
   constant BD  : integer := 5;
   
   constant TRANSPARENT : integer := 15;
   constant OBJALPHA    : integer := 16;
   constant OBJPRIOH    : integer := 18;
   constant OBJPRIOL    : integer := 17;
   
   -- latch on hblank
   signal WND0_on           : std_logic := '0';
   signal WND1_on           : std_logic := '0';
   signal WNDOBJ_on         : std_logic := '0';
    
   signal WND0_X1           : unsigned(7 downto 0) := (others => '0');
   signal WND0_X2           : unsigned(7 downto 0) := (others => '0');
   signal WND0_Y1           : unsigned(7 downto 0) := (others => '0');
   signal WND0_Y2           : unsigned(7 downto 0) := (others => '0');
   signal WND1_X1           : unsigned(7 downto 0) := (others => '0');
   signal WND1_X2           : unsigned(7 downto 0) := (others => '0');
   signal WND1_Y1           : unsigned(7 downto 0) := (others => '0');
   signal WND1_Y2           : unsigned(7 downto 0) := (others => '0');
    
   signal enables_wnd0      : std_logic_vector(5 downto 0) := (others => '0');
   signal enables_wnd1      : std_logic_vector(5 downto 0) := (others => '0');
   signal enables_wndobj    : std_logic_vector(5 downto 0) := (others => '0');
   signal enables_wndout    : std_logic_vector(5 downto 0) := (others => '0');
    
   signal special_effect_in : unsigned(1 downto 0) := (others => '0');
   signal effect_1st_bg0    : std_logic := '0';
   signal effect_1st_bg1    : std_logic := '0';
   signal effect_1st_bg2    : std_logic := '0';
   signal effect_1st_bg3    : std_logic := '0';
   signal effect_1st_obj    : std_logic := '0';
   signal effect_1st_BD     : std_logic := '0';
   signal effect_2nd_bg0    : std_logic := '0';
   signal effect_2nd_bg1    : std_logic := '0';
   signal effect_2nd_bg2    : std_logic := '0';
   signal effect_2nd_bg3    : std_logic := '0';
   signal effect_2nd_obj    : std_logic := '0';
   signal effect_2nd_BD     : std_logic := '0';
    
   signal Prio_BG0          : unsigned(1 downto 0) := (others => '0');
   signal Prio_BG1          : unsigned(1 downto 0) := (others => '0');
   signal Prio_BG2          : unsigned(1 downto 0) := (others => '0');
   signal Prio_BG3          : unsigned(1 downto 0) := (others => '0');
    
   signal EVA               : unsigned(4 downto 0) := (others => '0');
   signal EVB               : unsigned(4 downto 0) := (others => '0');
   signal BLDY              : unsigned(4 downto 0) := (others => '0');
   
   signal ena_bg0           : std_logic := '0';
   signal ena_bg1           : std_logic := '0';
   signal ena_bg2           : std_logic := '0';
   signal ena_bg3           : std_logic := '0';
   signal ena_obj           : std_logic := '0';
    
   -- common for whole line
   signal EVA_MAXED   : integer range 0 to 16;
   signal EVB_MAXED   : integer range 0 to 16;
   signal BLDY_MAXED  : integer range 0 to 16;
   
   signal anywindow     : std_logic := '0';
   signal inwin_0y      : std_logic := '0';
   signal inwin_1y      : std_logic := '0';
   
   signal first_target  : std_logic_vector(5 downto 0) := (others => '0');
   signal second_target : std_logic_vector(5 downto 0) := (others => '0');
   
   -- ####################################
   -- #### clock cycle one
   -- ####################################
   signal enable_cycle1         : std_logic;
   signal xpos_cycle1           : integer range 0 to 239;
   signal ypos_cycle1           : integer range 0 to 159;                 
   signal pixeldata_bg0_cycle1  : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_bg1_cycle1  : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_bg2_cycle1  : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_bg3_cycle1  : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_obj_cycle1  : std_logic_vector(18 downto 0) := (others => '0');
   -- new  
   signal enables_cycle1        : std_logic_vector(5 downto 0) := (others => '0');
   signal special_enable_cycle1 : std_logic;

   -- ####################################
   -- #### clock cycle two
   -- ####################################
   signal enable_cycle2           : std_logic;
   signal xpos_cycle2             : integer range 0 to 239;
   signal ypos_cycle2             : integer range 0 to 159;                 
   signal pixeldata_bg0_cycle2    : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_bg1_cycle2    : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_bg2_cycle2    : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_bg3_cycle2    : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_obj_cycle2    : std_logic_vector(18 downto 0) := (others => '0');  
   signal enables_cycle2          : std_logic_vector(5 downto 0) := (others => '0');
   signal special_enable_cycle2   : std_logic;
   -- new
   signal topprio_cycle2          : std_logic_vector(5 downto 0) := (others => '0');
   
   -- ####################################
   -- #### clock cycle three
   -- ####################################
   signal enable_cycle3           : std_logic;
   signal xpos_cycle3             : integer range 0 to 239;
   signal ypos_cycle3             : integer range 0 to 159;                 
   signal pixeldata_bg0_cycle3    : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_bg1_cycle3    : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_bg2_cycle3    : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_bg3_cycle3    : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_obj_cycle3    : std_logic_vector(18 downto 0) := (others => '0');  
   signal topprio_cycle3          : std_logic_vector(5 downto 0) := (others => '0');
   signal special_enable_cycle3   : std_logic;
   -- new
   signal firstprio_cycle3        : std_logic_vector(5 downto 0) := (others => '0');
   signal secondprio_cycle3       : std_logic_vector(5 downto 0) := (others => '0');
   signal firstpixel_cycle3       : std_logic_vector(14 downto 0) := (others => '0');
   
   -- ####################################
   -- #### clock cycle four
   -- ####################################
   signal enable_cycle4           : std_logic;
   signal xpos_cycle4             : integer range 0 to 239;
   signal ypos_cycle4             : integer range 0 to 159;                 
   signal pixeldata_bg0_cycle4    : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_bg1_cycle4    : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_bg2_cycle4    : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_bg3_cycle4    : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeldata_obj_cycle4    : std_logic_vector(18 downto 0) := (others => '0');  
   signal topprio_cycle4          : std_logic_vector(5 downto 0);
   -- new
   signal special_effect_cycle4   : unsigned(1 downto 0) := (others => '0');
   signal special_out_cycle4      : std_logic;
   signal alpha_red               : integer range 0 to 511;
   signal alpha_green             : integer range 0 to 511;
   signal alpha_blue              : integer range 0 to 511;   
   signal whiter_red              : integer range 0 to 511;
   signal whiter_green            : integer range 0 to 511;
   signal whiter_blue             : integer range 0 to 511;   
   signal blacker_red             : integer range -256 to 255;
   signal blacker_green           : integer range -256 to 255;
   signal blacker_blue            : integer range -256 to 255;
   
begin 

   -- ####################################
   -- #### latch on hsync
   -- ####################################
   process (clk100)
   begin
      if rising_edge(clk100) then
         if (hblank = '1') then
            WND0_on           <= in_WND0_on;          
            WND1_on           <= in_WND1_on;          
            WNDOBJ_on         <= in_WNDOBJ_on;        
               
            WND0_X1           <= in_WND0_X1;          
            WND0_X2           <= in_WND0_X2;          
            WND0_Y1           <= in_WND0_Y1;          
            WND0_Y2           <= in_WND0_Y2;          
            WND1_X1           <= in_WND1_X1;          
            WND1_X2           <= in_WND1_X2;          
            WND1_Y1           <= in_WND1_Y1;          
            WND1_Y2           <= in_WND1_Y2;          
                  
            enables_wnd0      <= in_enables_wnd0;     
            enables_wnd1      <= in_enables_wnd1;     
            enables_wndobj    <= in_enables_wndobj;   
            enables_wndout    <= in_enables_wndout;   
                           
            special_effect_in <= in_special_effect_in;
            effect_1st_bg0    <= in_effect_1st_bg0;   
            effect_1st_bg1    <= in_effect_1st_bg1;   
            effect_1st_bg2    <= in_effect_1st_bg2;   
            effect_1st_bg3    <= in_effect_1st_bg3;   
            effect_1st_obj    <= in_effect_1st_obj;   
            effect_1st_BD     <= in_effect_1st_BD;    
            effect_2nd_bg0    <= in_effect_2nd_bg0;   
            effect_2nd_bg1    <= in_effect_2nd_bg1;   
            effect_2nd_bg2    <= in_effect_2nd_bg2;   
            effect_2nd_bg3    <= in_effect_2nd_bg3;   
            effect_2nd_obj    <= in_effect_2nd_obj;   
            effect_2nd_BD     <= in_effect_2nd_BD;    
            
            Prio_BG0          <= in_Prio_BG0;         
            Prio_BG1          <= in_Prio_BG1;         
            Prio_BG2          <= in_Prio_BG2;         
            Prio_BG3          <= in_Prio_BG3;         
                           
            EVA               <= in_EVA;              
            EVB               <= in_EVB;              
            BLDY              <= in_BLDY; 

            ena_bg0           <= in_ena_bg0;
            ena_bg1           <= in_ena_bg1;
            ena_bg2           <= in_ena_bg2;
            ena_bg3           <= in_ena_bg3;
            ena_obj           <= in_ena_obj;
         end if;
      end if;
   end process;

   -- ####################################
   -- #### pipeline independent
   -- ####################################
   first_target  <= effect_1st_BD & effect_1st_obj & effect_1st_bg3 & effect_1st_bg2 & effect_1st_bg1 & effect_1st_bg0;
   second_target <= effect_2nd_BD & effect_2nd_obj & effect_2nd_bg3 & effect_2nd_bg2 & effect_2nd_bg1 & effect_2nd_bg0;
   
   process (clk100)
   begin
      if rising_edge(clk100) then

         if (EVA  < 16) then EVA_MAXED  <= to_integer(EVA);  else EVA_MAXED  <= 16; end if;
         if (EVB  < 16) then EVB_MAXED  <= to_integer(EVB);  else EVB_MAXED  <= 16; end if;
         if (BLDY < 16) then BLDY_MAXED <= to_integer(BLDY); else BLDY_MAXED <= 16; end if;

         -- windowcheck
         anywindow <= WND0_on or WND1_on or WNDOBJ_on;
            
         inwin_0y <= '0';
         if (WND0_on = '1') then
            if ((WND0_Y1 <= WND0_Y2 and  ypos >= WND0_Y1 and ypos < WND0_Y2) or
                (WND0_Y1  > WND0_Y2 and (ypos >= WND0_Y1  or ypos < WND0_Y2))) then  
               inwin_0y <= '1';
            end if;
         end if;
         inwin_1y <= '0';
         if (WND1_on = '1') then
            if ((WND1_Y1 <= WND1_Y2 and  ypos >= WND1_Y1 and ypos < WND1_Y2) or
                (WND1_Y1  > WND1_Y2 and (ypos >= WND1_Y1  or ypos < WND1_Y2))) then  
               inwin_1y <= '1';
            end if;
         end if;
         
      end if;
   end process;


   -- ####################################
   -- #### clock cycle zero
   -- ####################################
   process (clk100)
      variable enables_var    : std_logic_vector(4 downto 0);
   begin
      if rising_edge(clk100) then

         enable_cycle1        <= enable;      
         xpos_cycle1          <= xpos;        
         ypos_cycle1          <= ypos;        
         pixeldata_bg0_cycle1 <= pixeldata_bg0;
         pixeldata_bg1_cycle1 <= pixeldata_bg1;
         pixeldata_bg2_cycle1 <= pixeldata_bg2;
         pixeldata_bg3_cycle1 <= pixeldata_bg3;
         pixeldata_obj_cycle1 <= pixeldata_obj;
         
         -- base
         enables_var := not pixeldata_obj(TRANSPARENT) & 
                        not pixeldata_bg3(TRANSPARENT) & not pixeldata_bg2(TRANSPARENT) &
                        not pixeldata_bg1(TRANSPARENT) & not pixeldata_bg0(TRANSPARENT);
         
         -- window select
         special_enable_cycle1 <= '1';
         if (anywindow = '1') then
             if (inwin_0y = '1' and ((WND0_X1 <= WND0_X2 and xpos >= WND0_X1 and xpos < WND0_X2) or (WND0_X1 > WND0_X2 and (xpos >= WND0_X1 or xpos < WND0_X2)))) then
               special_enable_cycle1 <= enables_wnd0(5);
               enables_var           := enables_var and enables_wnd0(4 downto 0);
            elsif (inwin_1y = '1' and ((WND1_X1 <= WND1_X2 and xpos >= WND1_X1 and xpos < WND1_X2) or (WND1_X1 > WND1_X2 and (xpos >= WND1_X1 or xpos < WND1_X2)))) then
               special_enable_cycle1  <= enables_wnd1(5);
               enables_var            := enables_var and enables_wnd1(4 downto 0);
            elsif (objwindow_in = '1') then
               special_enable_cycle1  <= enables_wndobj(5);
               enables_var            := enables_var and enables_wndobj(4 downto 0);
            else
               special_enable_cycle1 <= enables_wndout(5);
               enables_var           := enables_var and enables_wndout(4 downto 0);
            end if;
         end if;
         enables_cycle1 <= '1' & enables_var; -- backdrop is always on
         
         if (ena_bg0 = '0') then enables_cycle1(0) <= '0'; end if;
         if (ena_bg1 = '0') then enables_cycle1(1) <= '0'; end if;
         if (ena_bg2 = '0') then enables_cycle1(2) <= '0'; end if;
         if (ena_bg3 = '0') then enables_cycle1(3) <= '0'; end if;
         if (ena_obj = '0') then enables_cycle1(4) <= '0'; end if;

      end if;
   end process;
   
   -- ####################################
   -- #### clock cycle one
   -- ####################################
   process (clk100)
      variable topprio_var : std_logic_vector(5 downto 0);
   begin
      if rising_edge(clk100) then

         enable_cycle2         <= enable_cycle1        ;
         xpos_cycle2           <= xpos_cycle1          ;   
         ypos_cycle2           <= ypos_cycle1          ;   
         pixeldata_bg0_cycle2  <= pixeldata_bg0_cycle1 ;   
         pixeldata_bg1_cycle2  <= pixeldata_bg1_cycle1 ;   
         pixeldata_bg2_cycle2  <= pixeldata_bg2_cycle1 ;   
         pixeldata_bg3_cycle2  <= pixeldata_bg3_cycle1 ;   
         pixeldata_obj_cycle2  <= pixeldata_obj_cycle1 ;   
         enables_cycle2        <= enables_cycle1       ;
         special_enable_cycle2 <= special_enable_cycle1;
         
         -- priority
         topprio_var := enables_cycle1;
         
         if (topprio_var(BG0) = '1' and topprio_var(OBJ) = '1' and unsigned(pixeldata_obj_cycle1(OBJPRIOH downto OBJPRIOL)) > Prio_BG0) then topprio_var(OBJ) := '0'; end if;
         if (topprio_var(BG1) = '1' and topprio_var(OBJ) = '1' and unsigned(pixeldata_obj_cycle1(OBJPRIOH downto OBJPRIOL)) > Prio_BG1) then topprio_var(OBJ) := '0'; end if;
         if (topprio_var(BG2) = '1' and topprio_var(OBJ) = '1' and unsigned(pixeldata_obj_cycle1(OBJPRIOH downto OBJPRIOL)) > Prio_BG2) then topprio_var(OBJ) := '0'; end if;
         if (topprio_var(BG3) = '1' and topprio_var(OBJ) = '1' and unsigned(pixeldata_obj_cycle1(OBJPRIOH downto OBJPRIOL)) > Prio_BG3) then topprio_var(OBJ) := '0'; end if;
         
         if (topprio_var(BG0) = '1' and topprio_var(BG1) = '1' and Prio_BG0 > Prio_BG1) then topprio_var(BG0) := '0'; end if;
         if (topprio_var(BG0) = '1' and topprio_var(BG2) = '1' and Prio_BG0 > Prio_BG2) then topprio_var(BG0) := '0'; end if;
         if (topprio_var(BG0) = '1' and topprio_var(BG3) = '1' and Prio_BG0 > Prio_BG3) then topprio_var(BG0) := '0'; end if;
         if (topprio_var(BG1) = '1' and topprio_var(BG2) = '1' and Prio_BG1 > Prio_BG2) then topprio_var(BG1) := '0'; end if;
         if (topprio_var(BG1) = '1' and topprio_var(BG3) = '1' and Prio_BG1 > Prio_BG3) then topprio_var(BG1) := '0'; end if;
         if (topprio_var(BG2) = '1' and topprio_var(BG3) = '1' and Prio_BG2 > Prio_BG3) then topprio_var(BG2) := '0'; end if;
            
         if    (topprio_var(OBJ) = '1') then topprio_var := "010000";
         elsif (topprio_var(BG0) = '1') then topprio_var := "000001";
         elsif (topprio_var(BG1) = '1') then topprio_var := "000010";
         elsif (topprio_var(BG2) = '1') then topprio_var := "000100";
         elsif (topprio_var(BG3) = '1') then topprio_var := "001000";
         else                                topprio_var := "100000"; end if;

         topprio_cycle2 <= topprio_var;

      
      end if;
   end process;
   
   
   -- ####################################
   -- #### clock cycle two
   -- ####################################
   process (clk100)
      variable firstprio_var  : std_logic_vector(5 downto 0);
      variable secondprio_var : std_logic_vector(5 downto 0);
   begin
      if rising_edge(clk100) then
         
         enable_cycle3           <= enable_cycle2        ;
         xpos_cycle3             <= xpos_cycle2          ;
         ypos_cycle3             <= ypos_cycle2          ;
         pixeldata_bg0_cycle3    <= pixeldata_bg0_cycle2 ;
         pixeldata_bg1_cycle3    <= pixeldata_bg1_cycle2 ;
         pixeldata_bg2_cycle3    <= pixeldata_bg2_cycle2 ;
         pixeldata_bg3_cycle3    <= pixeldata_bg3_cycle2 ;
         pixeldata_obj_cycle3    <= pixeldata_obj_cycle2 ;      
         topprio_cycle3          <= topprio_cycle2       ;
         special_enable_cycle3   <= special_enable_cycle2;
      
         -- priority first + second
         firstprio_var := enables_cycle2 and first_target;
         if (pixeldata_obj_cycle2(OBJALPHA) = '1') then 
            firstprio_var(OBJ) := '1';
         end if;
         firstprio_var := firstprio_var and topprio_cycle2;
         
         firstprio_cycle3 <= firstprio_var;
         
         
         secondprio_var := enables_cycle2 and (not firstprio_var);
         
         if (secondprio_var(BG0) = '1' and secondprio_var(OBJ) = '1' and unsigned(pixeldata_obj_cycle2(OBJPRIOH downto OBJPRIOL)) > Prio_BG0) then secondprio_var(OBJ) := '0'; end if;
         if (secondprio_var(BG1) = '1' and secondprio_var(OBJ) = '1' and unsigned(pixeldata_obj_cycle2(OBJPRIOH downto OBJPRIOL)) > Prio_BG1) then secondprio_var(OBJ) := '0'; end if;
         if (secondprio_var(BG2) = '1' and secondprio_var(OBJ) = '1' and unsigned(pixeldata_obj_cycle2(OBJPRIOH downto OBJPRIOL)) > Prio_BG2) then secondprio_var(OBJ) := '0'; end if;
         if (secondprio_var(BG3) = '1' and secondprio_var(OBJ) = '1' and unsigned(pixeldata_obj_cycle2(OBJPRIOH downto OBJPRIOL)) > Prio_BG3) then secondprio_var(OBJ) := '0'; end if;

         if (secondprio_var(BG0) = '1' and secondprio_var(BG1) = '1' and Prio_BG0 > Prio_BG1) then secondprio_var(BG0) := '0'; end if;
         if (secondprio_var(BG0) = '1' and secondprio_var(BG2) = '1' and Prio_BG0 > Prio_BG2) then secondprio_var(BG0) := '0'; end if;
         if (secondprio_var(BG0) = '1' and secondprio_var(BG3) = '1' and Prio_BG0 > Prio_BG3) then secondprio_var(BG0) := '0'; end if;
         if (secondprio_var(BG1) = '1' and secondprio_var(BG2) = '1' and Prio_BG1 > Prio_BG2) then secondprio_var(BG1) := '0'; end if;
         if (secondprio_var(BG1) = '1' and secondprio_var(BG3) = '1' and Prio_BG1 > Prio_BG3) then secondprio_var(BG1) := '0'; end if;
         if (secondprio_var(BG2) = '1' and secondprio_var(BG3) = '1' and Prio_BG2 > Prio_BG3) then secondprio_var(BG2) := '0'; end if;

         if    (secondprio_var(OBJ) = '1') then secondprio_var := "010000";
         elsif (secondprio_var(BG0) = '1') then secondprio_var := "000001";
         elsif (secondprio_var(BG1) = '1') then secondprio_var := "000010";
         elsif (secondprio_var(BG2) = '1') then secondprio_var := "000100";
         elsif (secondprio_var(BG3) = '1') then secondprio_var := "001000";
         else                                   secondprio_var := "100000"; end if;

         secondprio_cycle3 <= secondprio_var and second_target;
         
         -- special effect data
         firstpixel_cycle3 <= (others => '0');
         if    (firstprio_var(OBJ) = '1')  then firstpixel_cycle3 <= pixeldata_obj_cycle2(14 downto 0);
         elsif (firstprio_var(BG0) = '1')  then firstpixel_cycle3 <= pixeldata_bg0_cycle2(14 downto 0);
         elsif (firstprio_var(BG1) = '1')  then firstpixel_cycle3 <= pixeldata_bg1_cycle2(14 downto 0);
         elsif (firstprio_var(BG2) = '1')  then firstpixel_cycle3 <= pixeldata_bg2_cycle2(14 downto 0);
         elsif (firstprio_var(BG3) = '1')  then firstpixel_cycle3 <= pixeldata_bg3_cycle2(14 downto 0); 
         else                                   firstpixel_cycle3 <= pixeldata_back(14 downto 0); end if;
      
      end if;
   end process;
   
   
   -- ####################################
   -- #### clock cycle three
   -- ####################################
   process (clk100)
      variable special_effect_var : unsigned(1 downto 0);
      variable secondpixel        : std_logic_vector(14 downto 0);
   begin
      if rising_edge(clk100) then
         
         enable_cycle4           <= enable_cycle3       ;
         xpos_cycle4             <= xpos_cycle3         ;
         ypos_cycle4             <= ypos_cycle3         ;
         pixeldata_bg0_cycle4    <= pixeldata_bg0_cycle3;
         pixeldata_bg1_cycle4    <= pixeldata_bg1_cycle3;
         pixeldata_bg2_cycle4    <= pixeldata_bg2_cycle3;
         pixeldata_bg3_cycle4    <= pixeldata_bg3_cycle3;
         pixeldata_obj_cycle4    <= pixeldata_obj_cycle3;
         topprio_cycle4          <= topprio_cycle3      ;
         
         -- special effect control
         special_effect_var   := special_effect_in;
         special_out_cycle4   <= '0';

         if (special_enable_cycle3 = '1' and special_effect_in > 0) then
      
            if (firstprio_cycle3 /= "000000") then
            
               if (special_effect_in = "01") then

                  if (secondprio_cycle3 /= "000000") then
                     special_out_cycle4  <= '1';
                  end if;
               
               else
               
                  special_out_cycle4  <= '1';
               
               end if;
      
      
            end if;
            
         end if;
         
         if (pixeldata_obj_cycle3(OBJALPHA) = '1' and firstprio_cycle3(4 downto 0) = "10000" and secondprio_cycle3 /= "000000") then
            special_effect_var := "01";
            special_out_cycle4 <= '1';
         end if;
         
         if (special_effect_var > 1 and firstprio_cycle3(4 downto 0) = "10000" and effect_1st_obj = '0') then
            special_out_cycle4 <= '0';
         end if;

         special_effect_cycle4 <= special_effect_var;
      
         -- special effect data
         secondpixel := (others => '0');
         if    (secondprio_cycle3(OBJ) = '1') then secondpixel := pixeldata_obj_cycle3(14 downto 0);
         elsif (secondprio_cycle3(BG0) = '1') then secondpixel := pixeldata_bg0_cycle3(14 downto 0);
         elsif (secondprio_cycle3(BG1) = '1') then secondpixel := pixeldata_bg1_cycle3(14 downto 0);
         elsif (secondprio_cycle3(BG2) = '1') then secondpixel := pixeldata_bg2_cycle3(14 downto 0);
         elsif (secondprio_cycle3(BG3) = '1') then secondpixel := pixeldata_bg3_cycle3(14 downto 0); 
         else  secondpixel := pixeldata_back(14 downto 0); end if;

         alpha_blue    <= (to_integer(unsigned(firstpixel_cycle3(14 downto 10))) * EVA_MAXED + to_integer(unsigned(secondpixel(14 downto 10))) * EVB_MAXED) / 16;
         alpha_green   <= (to_integer(unsigned(firstpixel_cycle3( 9 downto  5))) * EVA_MAXED + to_integer(unsigned(secondpixel( 9 downto  5))) * EVB_MAXED) / 16;
         alpha_red     <= (to_integer(unsigned(firstpixel_cycle3( 4 downto  0))) * EVA_MAXED + to_integer(unsigned(secondpixel( 4 downto  0))) * EVB_MAXED) / 16;
         
         whiter_blue   <= to_integer(unsigned(firstpixel_cycle3(14 downto 10))) + (((31 - to_integer(unsigned(firstpixel_cycle3(14 downto 10)))) * BLDY_MAXED) / 16);
         whiter_green  <= to_integer(unsigned(firstpixel_cycle3( 9 downto  5))) + (((31 - to_integer(unsigned(firstpixel_cycle3( 9 downto  5)))) * BLDY_MAXED) / 16);
         whiter_red    <= to_integer(unsigned(firstpixel_cycle3( 4 downto  0))) + (((31 - to_integer(unsigned(firstpixel_cycle3( 4 downto  0)))) * BLDY_MAXED) / 16);
         
         blacker_blue  <= to_integer(unsigned(firstpixel_cycle3(14 downto 10))) - ((to_integer(unsigned(firstpixel_cycle3(14 downto 10))) * BLDY_MAXED) / 16);
         blacker_green <= to_integer(unsigned(firstpixel_cycle3( 9 downto  5))) - ((to_integer(unsigned(firstpixel_cycle3( 9 downto  5))) * BLDY_MAXED) / 16);
         blacker_red   <= to_integer(unsigned(firstpixel_cycle3( 4 downto  0))) - ((to_integer(unsigned(firstpixel_cycle3( 4 downto  0))) * BLDY_MAXED) / 16);
      
      end if;
   end process;
   
   
   -- ####################################
   -- #### clock cycle four
   -- ####################################
   process (clk100)
      variable special_pixel : unsigned(14 downto 0);
   begin
      if rising_edge(clk100) then

         pixel_we <= '0';
         
         if (enable_cycle4 = '1') then
         
            if (special_out_cycle4 = '1') then
            
               case (to_integer(special_effect_cycle4)) is
                  when 1 => -- alpha
                     if (alpha_blue  < 31) then pixeldata_out(14 downto 10) <= std_logic_vector(to_unsigned(alpha_blue , 5)); else pixeldata_out(14 downto 10) <= "11111"; end if;
                     if (alpha_green < 31) then pixeldata_out( 9 downto  5) <= std_logic_vector(to_unsigned(alpha_green, 5)); else pixeldata_out( 9 downto  5) <= "11111"; end if;
                     if (alpha_red   < 31) then pixeldata_out( 4 downto  0) <= std_logic_vector(to_unsigned(alpha_red  , 5)); else pixeldata_out( 4 downto  0) <= "11111"; end if;
                  
                  when 2 => -- whiter
                     if (whiter_blue  < 31) then pixeldata_out(14 downto 10) <= std_logic_vector(to_unsigned(whiter_blue , 5)); else pixeldata_out(14 downto 10) <= "11111"; end if;
                     if (whiter_green < 31) then pixeldata_out( 9 downto  5) <= std_logic_vector(to_unsigned(whiter_green, 5)); else pixeldata_out( 9 downto  5) <= "11111"; end if;
                     if (whiter_red   < 31) then pixeldata_out( 4 downto  0) <= std_logic_vector(to_unsigned(whiter_red  , 5)); else pixeldata_out( 4 downto  0) <= "11111"; end if;
                  
                  when 3 => -- blacker
                     if (blacker_blue  > 0) then pixeldata_out(14 downto 10) <= std_logic_vector(to_unsigned(blacker_blue , 5)); else pixeldata_out(14 downto 10) <= "00000"; end if;
                     if (blacker_green > 0) then pixeldata_out( 9 downto  5) <= std_logic_vector(to_unsigned(blacker_green, 5)); else pixeldata_out( 9 downto  5) <= "00000"; end if;
                     if (blacker_red   > 0) then pixeldata_out( 4 downto  0) <= std_logic_vector(to_unsigned(blacker_red  , 5)); else pixeldata_out( 4 downto  0) <= "00000"; end if;
      
                  when others => null;
               end case;
            
            elsif (topprio_cycle4(OBJ) = '1') then
               pixeldata_out <= pixeldata_obj_cycle4(15 downto 0);
            elsif (topprio_cycle4(BG0) = '1') then
               pixeldata_out <= pixeldata_bg0_cycle4;
            elsif (topprio_cycle4(BG1) = '1') then
               pixeldata_out <= pixeldata_bg1_cycle4;
            elsif (topprio_cycle4(BG2) = '1') then
               pixeldata_out <= pixeldata_bg2_cycle4;
            elsif (topprio_cycle4(BG3) = '1') then
               pixeldata_out <= pixeldata_bg3_cycle4;
            else
               pixeldata_out <= pixeldata_back;
            end if;
         
            pixel_x       <= xpos_cycle4;
            pixel_y       <= ypos_cycle4;
            pixel_we      <= '1';

         end if;
      
      end if;
   end process;
   

end architecture;





