library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     
use STD.textio.all;

use work.pProc_bus_gba.all;
use work.pReg_savestates.all;

entity gba_cpu is
   generic
   (
      is_simu : std_logic
   );
   port 
   (
      clk100           : in    std_logic;  
      gb_on            : in    std_logic;
      reset            : in    std_logic;
      
      savestate_bus    : inout proc_bus_gb_type;
      
      gb_bus_Adr       : out   std_logic_vector(31 downto 0);
      gb_bus_rnw       : out   std_logic;
      gb_bus_ena       : out   std_logic;
      gb_bus_acc       : out   std_logic_vector(1 downto 0);
      gb_bus_dout      : out   std_logic_vector(31 downto 0);
      gb_bus_din       : in    std_logic_vector(31 downto 0);
      gb_bus_done      : in    std_logic;
        
      wait_cnt_value   : in    unsigned(14 downto 0);
      wait_cnt_update  : in    std_logic;
        
      bus_lowbits      : out   std_logic_vector(1 downto 0) := "00";
        
      settle           : in    std_logic;
      dma_on           : in    std_logic;
      do_step          : in    std_logic;
      done             : buffer std_logic := '0';
      CPU_bus_idle     : out   std_logic;
      PC_in_BIOS       : out   std_logic;
      lastread         : out   std_logic_vector(31 downto 0);
      jump_out         : out   std_logic;
      
      new_cycles_out   : buffer unsigned(7 downto 0) := (others => '0');
      new_cycles_valid : buffer std_logic := '0';
      
      dma_new_cycles   : in    std_logic := '0'; 
      dma_first_cycles : in    std_logic := '0';
      dma_dword_cycles : in    std_logic := '0';
      dma_toROM        : in    std_logic := '0';
      dma_init_cycles  : in    std_logic := '0';
      dma_cycles_adrup : in    std_logic_vector(3 downto 0) := (others => '0'); 
      
      IRP_in           : in    std_logic_vector(15 downto 0);
      cpu_IRP          : in    std_logic;
      new_halt         : in    std_logic;
      
      DISPSTAT_debug   : in    std_logic_vector(31 downto 0);
      debug_fifocount  : in    integer;
      
      timerdebug0      : in    std_logic_vector(31 downto 0);
      timerdebug1      : in    std_logic_vector(31 downto 0);
      timerdebug2      : in    std_logic_vector(31 downto 0);
      timerdebug3      : in    std_logic_vector(31 downto 0);
      
-- synthesis translate_off
      cyclenr          : buffer integer := 0;
      cyclecount       : buffer integer := 0;
      cyclesum         : buffer integer := 0;
-- synthesis translate_on     
	  
      debug_cpu_pc     : out   std_logic_vector(31 downto 0);
      debug_cpu_mixed  : out   std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of gba_cpu is

   constant gbbusadr_bits : integer := work.pProc_bus_gba.proc_busadr;

   -- ####################################
   -- ARM processor regs and states 
   -- ####################################
    
   constant CPUMODE_USER       : std_logic_vector(3 downto 0) := x"0";
   constant CPUMODE_FIQ        : std_logic_vector(3 downto 0) := x"1";
   constant CPUMODE_IRQ        : std_logic_vector(3 downto 0) := x"2";
   constant CPUMODE_SUPERVISOR : std_logic_vector(3 downto 0) := x"3";
   constant CPUMODE_ABORT      : std_logic_vector(3 downto 0) := x"7";
   constant CPUMODE_UNDEFINED  : std_logic_vector(3 downto 0) := x"B";
   constant CPUMODE_SYSTEM     : std_logic_vector(3 downto 0) := x"F";
   
   signal thumbmode        : std_logic := '0';
   signal halt             : std_logic := '0';
         
   signal IRQ_disable      : std_logic := '1';
   signal FIQ_disable      : std_logic := '1';
   
   signal Flag_Zero        : std_logic := '0';
   signal Flag_Carry       : std_logic := '0';
   signal Flag_Negative    : std_logic := '0';
   signal Flag_V_Overflow  : std_logic := '0';
   
   signal cpu_mode         : std_logic_vector(3 downto 0) := CPUMODE_SUPERVISOR;
   signal cpu_mode_old     : std_logic_vector(3 downto 0) := (others => '0');

   type t_regs is array(0 to 17) of unsigned(31 downto 0);
   signal regs : t_regs := (others => (others => '0'));
   signal regs_plus_12  : unsigned(31 downto 0);
   signal block_pc_next : unsigned(31 downto 0);

   signal PC               : unsigned(31 downto 0) := (others => '0');

   signal regs_0_8  : unsigned(31 downto 0) := (others => '0');
   signal regs_0_9  : unsigned(31 downto 0) := (others => '0');
   signal regs_0_10 : unsigned(31 downto 0) := (others => '0');
   signal regs_0_11 : unsigned(31 downto 0) := (others => '0');
   signal regs_0_12 : unsigned(31 downto 0) := (others => '0');
   signal regs_0_13 : unsigned(31 downto 0) := (others => '0');
   signal regs_0_14 : unsigned(31 downto 0) := (others => '0');
   signal regs_1_8  : unsigned(31 downto 0) := (others => '0');
   signal regs_1_9  : unsigned(31 downto 0) := (others => '0');
   signal regs_1_10 : unsigned(31 downto 0) := (others => '0');
   signal regs_1_11 : unsigned(31 downto 0) := (others => '0');
   signal regs_1_12 : unsigned(31 downto 0) := (others => '0');
   signal regs_1_13 : unsigned(31 downto 0) := (others => '0');
   signal regs_1_14 : unsigned(31 downto 0) := (others => '0');
   signal regs_1_17 : unsigned(31 downto 0) := (others => '0');
   signal regs_2_13 : unsigned(31 downto 0) := (others => '0');
   signal regs_2_14 : unsigned(31 downto 0) := (others => '0');
   signal regs_2_17 : unsigned(31 downto 0) := (others => '0');
   signal regs_3_13 : unsigned(31 downto 0) := (others => '0');
   signal regs_3_14 : unsigned(31 downto 0) := (others => '0');
   signal regs_3_17 : unsigned(31 downto 0) := (others => '0');
   signal regs_4_13 : unsigned(31 downto 0) := (others => '0');
   signal regs_4_14 : unsigned(31 downto 0) := (others => '0');
   signal regs_4_17 : unsigned(31 downto 0) := (others => '0');
   signal regs_5_13 : unsigned(31 downto 0) := (others => '0');
   signal regs_5_14 : unsigned(31 downto 0) := (others => '0');
   signal regs_5_17 : unsigned(31 downto 0) := (others => '0');
       
   -- ####################################
   -- internal calculation signals
   -- ####################################
   
   signal jump         : std_logic := '0';
   signal new_pc       : unsigned(31 downto 0) := (others => '0');
   signal branchnext   : std_logic := '0';
   signal blockr15jump : std_logic := '0';
   
   -- ############# Timing ##############
   
   signal decode_cycles      : integer range 0 to 15 := 0;
   signal execute_cycles     : integer range 0 to 255 := 0;
   signal execute_addcycles  : integer range 0 to 31 := 0;
   
   signal dataticksAccess16        : integer range 0 to 31 := 0;
   signal dataticksAccess32        : integer range 0 to 31 := 0;
   signal dataticksAccessSeq32     : integer range 0 to 31 := 0;
   signal codeticksAccess16        : integer range 0 to 31 := 0;
   signal codeticksAccess32        : integer range 0 to 31 := 0;
   signal codeticksAccessSeq16     : integer range 0 to 31 := 0;
   signal codeticksAccessSeq32     : integer range 0 to 31 := 0;
   signal codeticksAccessJump16    : integer range 0 to 31 := 0;
   signal codeticksAccessJump32    : integer range 0 to 31 := 0;
   signal codeticksAccessSeqJump16 : integer range 0 to 31 := 0;
   signal codeticksAccessSeqJump32 : integer range 0 to 31 := 0;
   
   signal codeticksAccess1632    : integer range 0 to 31 := 0;
   signal codeticksAccessSeq1632 : integer range 0 to 31 := 0;
   
   signal codeBaseAccess1632    : integer range 0 to 31 := 0;
   signal codeBaseAccessSeq1632 : integer range 0 to 31 := 0;
   
   signal nextOpCodeAccessSeq16 : integer range 0 to 31 := 0;
   signal nextOpCodeAccessSeq32 : integer range 0 to 31 := 0;
   
   type t_timingarray is array(0 to 15) of integer range 0 to 31;
   signal memoryWait16    : t_timingarray := (0, 0, 2, 0, 0, 0, 0, 0, 4, 4, 4, 4,  4,  4, 4, 0);
   signal memoryWait32    : t_timingarray := (0, 0, 5, 0, 0, 1, 1, 0, 7, 7, 9, 9, 13, 13, 4, 0);
   signal memoryWaitSeq16 : t_timingarray := (0, 0, 2, 0, 0, 0, 0, 0, 2, 2, 4, 4,  8,  8, 4, 0);
   signal memoryWaitSeq32 : t_timingarray := (0, 0, 5, 0, 0, 1, 1, 0, 5, 5, 9, 9, 17, 17, 4, 0);
   
   type t_timings_2 is array(0 to 1) of integer range 1 to 8;
   type t_timings_4 is array(0 to 3) of integer range 1 to 8;
   constant gamepakRamWaitState : t_timings_4 := ( 4, 3, 2, 8);
   constant gamepakWaitState    : t_timings_4 := ( 4, 3, 2, 8);
   constant gamepakWaitState0   : t_timings_2 := ( 2, 1);
   constant gamepakWaitState1   : t_timings_2 := ( 4, 1);
   constant gamepakWaitState2   : t_timings_2 := ( 8, 1);
   
   signal wait_cnt_update_1 : std_logic := '0';
   
   signal busPrefetchEnable  : std_logic := '0';
   signal busPrefetchAdd     : std_logic := '0';
   signal busPrefetchSub     : std_logic := '0';
   signal busPrefetchClear   : std_logic := '0';
   signal busPrefetchCnt     : integer range 0 to 64;
   signal busPrefetchMax     : integer range 0 to 64;
   signal prefetch_addcycles : integer range 0 to 31;
   signal prefetch_subcycles : integer range 0 to 31;
   
   -- ############# Fetch ##############
   
   signal wait_fetch         : std_logic := '0';   
   signal skip_pending_fetch : std_logic := '0';   
   signal fetch_ack          : std_logic := '0';   
   signal fetch_available    : std_logic := '0'; 
   signal fetch_data         : std_logic_vector(31 downto 0) := (others => '0');  
   
   -- ############# Decode ##############
   
   signal decode_request   : std_logic := '0';
   signal decode_data      : std_logic_vector(31 downto 0) := (others => '0');
   signal decode_PC        : unsigned(31 downto 0) := (others => '0');
   signal decode_condition : std_logic_vector(3 downto 0);
   
   type tState_decode is
   (
      WAITFETCH,
      DECODE_DETAILS,
      DECODE_DONE
   );
   signal state_decode : tState_decode;
   
   -- ############# Execute ##############
   
   signal execute_request : std_logic;
   signal execute_start   : std_logic := '0';
   signal calc_done       : std_logic := '0';
   signal executebus      : std_logic := '0';
   signal execute_PC      : unsigned(31 downto 0) := (others => '0');
   signal execute_PCprev  : unsigned(31 downto 0) := (others => '0');
   
   signal halt_cnt        : integer range 0 to 5 := 0;
   signal irq_calc        : std_logic := '0';
   signal irq_delay       : integer range 0 to 4;
   signal irq_triggerhold : std_logic := '0';
   
   signal calc_result               : unsigned(31 downto 0);
   signal writeback_reg             : std_logic_vector(3 downto 0) := (others => '0');
   signal execute_writeback_calc    : std_logic := '0';
   signal execute_writeback_r17     : std_logic := '0';
   signal execute_writeback_userreg : std_logic := '0';
   signal execute_switchregs        : std_logic := '0';
   signal execute_saveregs          : std_logic := '0';
   signal execute_saveState         : std_logic := '0';
   signal execute_SWI               : std_logic := '0';
   signal execute_IRP               : std_logic := '0';
   
   type tState_execute is
   (
      FETCH_OP,
      CALC
   );
   signal state_execute : tState_execute;
   
   -- ############# Functions ##############
   
   type tFunctions is
   (
      -- arm/combined
      branch_and_exchange,
      data_processing,
      single_data_swap,
      multiply_long,
      multiply,
      halfword_data_transfer_regoffset,
      halfword_data_transfer_immoffset,
      single_data_transfer,
      block_data_transfer,
      branch,
      software_interrupt,
      -- thumb
      long_branch_with_link
   );

   type tFunctions_detail is
   (
      alu_and,
      alu_xor,
      alu_sub,
      alu_add,
      alu_add_withcarry,
      alu_sub_withcarry,
      alu_or,
      alu_mov,
      alu_and_not,
      alu_mov_not,
      mulboth,
      data_processing_MRS,
      data_processing_MSR,
      branch_all,
      data_read,
      data_write,
      block_read,
      block_write,
      software_interrupt_detail,
      long_branch_with_link_low
   );
   
   type tdatareceivetype is
   (
      RECEIVETYPE_BYTE,
      RECEIVETYPE_DWORD,
      RECEIVETYPE_WORD,
      RECEIVETYPE_SIGNEDBYTE,
      RECEIVETYPE_SIGNEDWORD
   );
   
   signal decode_functions_detail : tFunctions_detail;
   signal decode_datareceivetype  : tdatareceivetype;
   signal decode_clearbit1                : std_logic := '0';
   signal decode_rdest                    : std_logic_vector(3 downto 0) := (others => '0');
   signal decode_Rn_op1                   : std_logic_vector(3 downto 0) := (others => '0');
   signal decode_RM_op2                   : std_logic_vector(3 downto 0) := (others => '0');
   signal decode_alu_use_immi             : std_logic := '0';
   signal decode_alu_use_shift            : std_logic := '0';
   signal decode_immidiate                : unsigned(31 downto 0) := (others => '0');
   signal decode_shiftsettings            : std_logic_vector(7 downto 0) := (others => '0');
   signal decode_shiftcarry               : std_logic := '0';
   signal decode_useoldcarry              : std_logic := '0';
   signal decode_updateflags              : std_logic := '0';
   signal decode_muladd                   : std_logic_vector(3 downto 0) := (others => '0');
   signal decode_mul_signed               : std_logic := '0';
   signal decode_mul_useadd               : std_logic := '0';
   signal decode_mul_long                 : std_logic := '0';
   signal decode_writeback                : std_logic := '0';
   signal decode_switch_op                : std_logic := '0';
   signal decode_set_thumbmode            : std_logic := '0';
   signal decode_branch_usereg            : std_logic := '0';
   signal decode_branch_link              : std_logic := '0';
   signal decode_branch_immi              : signed(25 downto 0) := (others => '0');
   signal decode_datatransfer_type        : std_logic_vector(1 downto 0) := (others => '0');
   signal decode_datatransfer_preadd      : std_logic := '0';
   signal decode_datatransfer_addup       : std_logic := '0';
   signal decode_datatransfer_writeback   : std_logic := '0';
   signal decode_datatransfer_addvalue    : unsigned(11 downto 0)  := (others => '0');
   signal decode_datatransfer_shiftval    : std_logic := '0';
   signal decode_datatransfer_regoffset   : std_logic := '0';
   signal decode_datatransfer_swap        : std_logic := '0';
   signal decode_block_usermoderegs       : std_logic := '0';
   signal decode_block_switchmode         : std_logic := '0';
   signal decode_block_addrmod            : integer range -64 to 64 := 0;
   signal decode_block_endmod             : integer range -64 to 64 := 0;
   signal decode_block_addrmod_baseRlist  : integer range -64 to 64 := 0;
   signal decode_block_reglist            : std_logic_vector(15 downto 0) := (others => '0');
   signal decode_block_emptylist          : std_logic := '0';
   signal decode_psr_with_spsr            : std_logic := '0';
   signal decode_leaveirp                 : std_logic := '0';
   signal decode_leaveirp_user            : std_logic := '0';
   
   signal execute_functions_detail : tFunctions_detail;
   signal execute_datareceivetype  : tdatareceivetype;
   signal execute_clearbit1               : std_logic := '0';
   signal execute_rdest                   : std_logic_vector(3 downto 0) := (others => '0');
   signal execute_Rn_op1                  : std_logic_vector(3 downto 0) := (others => '0');
   signal execute_RM_op2                  : std_logic_vector(3 downto 0) := (others => '0');
   signal execute_alu_use_immi            : std_logic := '0';
   signal execute_alu_use_shift           : std_logic := '0';
   signal execute_immidiate               : unsigned(31 downto 0) := (others => '0');
   signal execute_shiftsettings           : std_logic_vector(7 downto 0) := (others => '0');
   signal execute_shiftcarry              : std_logic := '0';
   signal execute_useoldcarry             : std_logic := '0';
   signal execute_updateflags             : std_logic := '0';
   signal execute_muladd                  : std_logic_vector(3 downto 0) := (others => '0');
   signal execute_mul_signed              : std_logic := '0';
   signal execute_mul_useadd              : std_logic := '0';
   signal execute_mul_long                : std_logic := '0';
   signal execute_writeback               : std_logic := '0';
   signal execute_switch_op               : std_logic := '0';
   signal execute_set_thumbmode           : std_logic := '0';
   signal execute_branch_usereg           : std_logic := '0';
   signal execute_branch_link             : std_logic := '0';
   signal execute_branch_immi             : signed(25 downto 0) := (others => '0');
   signal execute_datatransfer_type       : std_logic_vector(1 downto 0) := (others => '0');
   signal execute_datatransfer_preadd     : std_logic := '0';
   signal execute_datatransfer_addup      : std_logic := '0';
   signal execute_datatransfer_writeback  : std_logic := '0';
   signal execute_datatransfer_addvalue   : unsigned(11 downto 0)  := (others => '0');
   signal execute_datatransfer_shiftval   : std_logic := '0';
   signal execute_datatransfer_regoffset  : std_logic := '0';
   signal execute_datatransfer_swap       : std_logic := '0';
   signal execute_block_usermoderegs      : std_logic := '0';
   signal execute_block_switchmode        : std_logic := '0';
   signal execute_block_addrmod           : integer range -64 to 64 := 0;
   signal execute_block_endmod            : integer range -64 to 64 := 0;
   signal execute_block_addrmod_baseRlist : integer range -64 to 64 := 0;
   signal execute_block_reglist           : std_logic_vector(15 downto 0) := (others => '0');
   signal execute_block_emptylist         : std_logic := '0';
   signal execute_psr_with_spsr           : std_logic := '0';
   signal execute_leaveirp                : std_logic := '0';
   signal execute_leaveirp_user           : std_logic := '0';
   
   -- ############# ALU ##############
   type talu_stage is
   (
      ALUSTART,
      ALUSHIFT,
      ALUSHIFTWAIT,
      ALUSWITCHOP,
      ALUCALC,
      ALUSETFLAGS,
      ALULEAVEIRP
   );
   signal alu_stage : talu_stage := ALUSTART;
   
   signal alu_op1           : unsigned(31 downto 0);
   signal alu_op2           : unsigned(31 downto 0);
   signal alu_result        : unsigned(31 downto 0);
   signal alu_result_add    : unsigned(32 downto 0);
   signal alu_shiftercarry  : std_logic;
   
   -- ############# ALU ##############
   type tmul_stage is
   (
      MULSTART,
      MULCALCMUL,
      MULADDLOW,
      MULADDHIGH,
      MULSETFLAGS,
      MULWRITEBACK_LOW,
      MULWRITEBACK_HIGH
   );
   signal mul_stage : tmul_stage := MULSTART;
   
   signal mul_op1           : unsigned(31 downto 0);
   signal mul_op2           : unsigned(31 downto 0);
   signal mul_opaddlow      : unsigned(31 downto 0);
   signal mul_opaddhigh     : unsigned(31 downto 0);
   signal mul_result        : unsigned(63 downto 0);
   signal mul_wait          : integer range 0 to 3;
   
   -- ############# SHIFTER ##############
   
   signal shifter_start     : std_logic := '0';       
   signal shiftreg          : unsigned(31 downto 0) := (others => '0');
   signal shiftbyreg        : unsigned( 7 downto 0) := (others => '0');
   signal shiftresult       : unsigned(31 downto 0) := (others => '0');
   signal shiftercarry      : std_logic := '0';
   
   signal shiftwait         : integer range 0 to 2 := 0;
   signal shiftamount       : integer range 0 to 255 := 0;
   signal shiftervalue      : unsigned(31 downto 0) := (others => '0');
   signal shift_rrx         : std_logic := '0';
   
   signal shiftercarry_LSL  : std_logic := '0';
   signal shiftercarry_RSL  : std_logic := '0';
   signal shiftercarry_ARS  : std_logic := '0';
   signal shiftercarry_ROR  : std_logic := '0';
   signal shiftercarry_RRX  : std_logic := '0';

   signal shiftresult_LSL   : unsigned(31 downto 0) := (others => '0');
   signal shiftresult_RSL   : unsigned(31 downto 0) := (others => '0');
   signal shiftresult_ARS   : unsigned(31 downto 0) := (others => '0');
   signal shiftresult_ROR   : unsigned(31 downto 0) := (others => '0');
   signal shiftresult_RRX   : unsigned(31 downto 0) := (others => '0');    
   
   -- ############# BUS ##############
   
   signal bus_fetch_Adr    : std_logic_vector(31 downto 0);
   signal bus_fetch_rnw    : std_logic;
   signal bus_fetch_acc    : std_logic_vector(1 downto 0);
   
   signal bus_execute_Adr  : std_logic_vector(31 downto 0) := (others => '0');
   signal bus_execute_rnw  : std_logic := '0';
   signal bus_execute_ena  : std_logic := '0';
   signal bus_execute_acc  : std_logic_vector(1 downto 0) := (others => '0');
   
   type tbus_stage is
   (
      FETCHADDR,
      BUSSHIFT,
      BUSSHIFTWAIT,
      CALCADDR,
      BUSREQUEST,
      WAITBUS,
      WRITEBACKADDR
   );
   signal data_rw_stage : tbus_stage := FETCHADDR;
   
   signal busaddress       : unsigned(31 downto 0);
   signal busaddmod        : unsigned(31 downto 0);
   signal swap_write       : std_logic;
   signal first_mem_access : std_logic;
   
   -- ############# Block RW ##############
   
   type tblock_stage is
   (
      BLOCKFETCHADDR,
      BLOCKCHECKNEXT,
      BLOCKWRITE,
      BLOCKWAITWRITE,
      BLOCKREAD,
      BLOCKWAITREAD,
      BLOCKWRITEBACKADDR,
      BLOCKSWITCHMODE
   );
   signal block_rw_stage : tblock_stage := BLOCKFETCHADDR;
   
   signal block_regindex   : integer range 0 to 15;
   signal endaddress       : unsigned(31 downto 0) := (others => '0');
   signal endaddressRlist  : unsigned(31 downto 0) := (others => '0');
   signal block_writevalue : unsigned(31 downto 0) := (others => '0');
   signal block_reglist    : std_logic_vector(15 downto 0) := (others => '0');
   signal block_switch_pc  : unsigned(31 downto 0) := (others => '0');
   
   
   -- ############# MSR/MRS ##############
   type tMRS_stage is
   (
      MSR_START,
      MSR_SPSR,
      MSR_CPSR
   );
   signal MSR_Stage : tMRS_stage := MSR_START;
   
   signal msr_value            : unsigned(31 downto 0); 
   signal msr_writebackvalue   : unsigned(31 downto 0); 
   
   -- savestates
   signal SAVESTATE_PC : std_logic_vector(31 downto 0) := (others => '0');
   
   type t_regs_slv is array(0 to 17) of std_logic_vector(31 downto 0);
   signal SAVESTATE_REGS : t_regs_slv := (others => (others => '0'));
   
   signal SAVESTATE_REGS_0_8  : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_0_9  : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_0_10 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_0_11 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_0_12 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_0_13 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_0_14 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_1_8  : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_1_9  : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_1_10 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_1_11 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_1_12 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_1_13 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_1_14 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_1_17 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_2_13 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_2_14 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_2_17 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_3_13 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_3_14 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_3_17 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_4_13 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_4_14 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_4_17 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_5_13 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_5_14 : std_logic_vector(31 downto 0) := (others => '0');
   signal SAVESTATE_REGS_5_17 : std_logic_vector(31 downto 0) := (others => '0');
   
   signal SAVESTATE_HALT            : std_logic;
   signal SAVESTATE_Flag_Zero       : std_logic;
   signal SAVESTATE_Flag_Carry      : std_logic;
   signal SAVESTATE_Flag_Negative   : std_logic;
   signal SAVESTATE_Flag_V_Overflow : std_logic;
   signal SAVESTATE_thumbmode       : std_logic;
   signal SAVESTATE_cpu_mode        : std_logic_vector(3 downto 0);
   signal SAVESTATE_IRQ_disable     : std_logic;
   signal SAVESTATE_FIQ_disable     : std_logic;
   
   signal SAVESTATE_mixed_in        : std_logic_vector(11 downto 0);
   signal SAVESTATE_mixed_out       : std_logic_vector(11 downto 0);
     
begin  

   debug_cpu_pc <= std_logic_vector(PC);
   
   debug_cpu_mixed(0) <= halt;           
   debug_cpu_mixed(1) <= Flag_Zero;     
   debug_cpu_mixed(2) <= Flag_Carry;     
   debug_cpu_mixed(3) <= Flag_Negative;  
   debug_cpu_mixed(4) <= Flag_V_Overflow;
   debug_cpu_mixed(5) <= thumbmode;      
   debug_cpu_mixed(9 downto 6) <= cpu_mode;       
   debug_cpu_mixed(10) <= IRQ_disable;    
   debug_cpu_mixed(11) <= FIQ_disable; 
   debug_cpu_mixed(31 downto 12) <= (others => '0');
   
   -- savestates
   iSAVESTATE_PC : entity work.eProcReg_gba generic map (REG_SAVESTATE_PC ) port map (clk100, savestate_bus, std_logic_vector(new_pc) , SAVESTATE_PC);
   gSAVESTATE_REGS : for i in 0 to 17 generate
   begin
      iSAVESTATE_REGS : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS, i) port map (clk100, savestate_bus, std_logic_vector(regs(i)) , SAVESTATE_REGS(i));
   end generate;
   iSAVESTATE_REGS_0_8  : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_0_8 ) port map (clk100, savestate_bus, std_logic_vector(regs_0_8 ) , SAVESTATE_REGS_0_8 );
   iSAVESTATE_REGS_0_9  : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_0_9 ) port map (clk100, savestate_bus, std_logic_vector(regs_0_9 ) , SAVESTATE_REGS_0_9 );
   iSAVESTATE_REGS_0_10 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_0_10) port map (clk100, savestate_bus, std_logic_vector(regs_0_10) , SAVESTATE_REGS_0_10);
   iSAVESTATE_REGS_0_11 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_0_11) port map (clk100, savestate_bus, std_logic_vector(regs_0_11) , SAVESTATE_REGS_0_11);
   iSAVESTATE_REGS_0_12 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_0_12) port map (clk100, savestate_bus, std_logic_vector(regs_0_12) , SAVESTATE_REGS_0_12);
   iSAVESTATE_REGS_0_13 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_0_13) port map (clk100, savestate_bus, std_logic_vector(regs_0_13) , SAVESTATE_REGS_0_13);
   iSAVESTATE_REGS_0_14 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_0_14) port map (clk100, savestate_bus, std_logic_vector(regs_0_14) , SAVESTATE_REGS_0_14);
   iSAVESTATE_REGS_1_8  : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_1_8 ) port map (clk100, savestate_bus, std_logic_vector(regs_1_8 ) , SAVESTATE_REGS_1_8 );
   iSAVESTATE_REGS_1_9  : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_1_9 ) port map (clk100, savestate_bus, std_logic_vector(regs_1_9 ) , SAVESTATE_REGS_1_9 );
   iSAVESTATE_REGS_1_10 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_1_10) port map (clk100, savestate_bus, std_logic_vector(regs_1_10) , SAVESTATE_REGS_1_10);
   iSAVESTATE_REGS_1_11 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_1_11) port map (clk100, savestate_bus, std_logic_vector(regs_1_11) , SAVESTATE_REGS_1_11);
   iSAVESTATE_REGS_1_12 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_1_12) port map (clk100, savestate_bus, std_logic_vector(regs_1_12) , SAVESTATE_REGS_1_12);
   iSAVESTATE_REGS_1_13 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_1_13) port map (clk100, savestate_bus, std_logic_vector(regs_1_13) , SAVESTATE_REGS_1_13);
   iSAVESTATE_REGS_1_14 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_1_14) port map (clk100, savestate_bus, std_logic_vector(regs_1_14) , SAVESTATE_REGS_1_14);
   iSAVESTATE_REGS_1_17 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_1_17) port map (clk100, savestate_bus, std_logic_vector(regs_1_17) , SAVESTATE_REGS_1_17);
   iSAVESTATE_REGS_2_13 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_2_13) port map (clk100, savestate_bus, std_logic_vector(regs_2_13) , SAVESTATE_REGS_2_13);
   iSAVESTATE_REGS_2_14 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_2_14) port map (clk100, savestate_bus, std_logic_vector(regs_2_14) , SAVESTATE_REGS_2_14);
   iSAVESTATE_REGS_2_17 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_2_17) port map (clk100, savestate_bus, std_logic_vector(regs_2_17) , SAVESTATE_REGS_2_17);
   iSAVESTATE_REGS_3_13 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_3_13) port map (clk100, savestate_bus, std_logic_vector(regs_3_13) , SAVESTATE_REGS_3_13);
   iSAVESTATE_REGS_3_14 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_3_14) port map (clk100, savestate_bus, std_logic_vector(regs_3_14) , SAVESTATE_REGS_3_14);
   iSAVESTATE_REGS_3_17 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_3_17) port map (clk100, savestate_bus, std_logic_vector(regs_3_17) , SAVESTATE_REGS_3_17);
   iSAVESTATE_REGS_4_13 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_4_13) port map (clk100, savestate_bus, std_logic_vector(regs_4_13) , SAVESTATE_REGS_4_13);
   iSAVESTATE_REGS_4_14 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_4_14) port map (clk100, savestate_bus, std_logic_vector(regs_4_14) , SAVESTATE_REGS_4_14);
   iSAVESTATE_REGS_4_17 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_4_17) port map (clk100, savestate_bus, std_logic_vector(regs_4_17) , SAVESTATE_REGS_4_17);
   iSAVESTATE_REGS_5_13 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_5_13) port map (clk100, savestate_bus, std_logic_vector(regs_5_13) , SAVESTATE_REGS_5_13);
   iSAVESTATE_REGS_5_14 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_5_14) port map (clk100, savestate_bus, std_logic_vector(regs_5_14) , SAVESTATE_REGS_5_14);
   iSAVESTATE_REGS_5_17 : entity work.eProcReg_gba generic map (REG_SAVESTATE_REGS_5_17) port map (clk100, savestate_bus, std_logic_vector(regs_5_17) , SAVESTATE_REGS_5_17);
   
   iSAVESTATE_CPUMIXED  : entity work.eProcReg_gba generic map (REG_SAVESTATE_CPUMIXED)  port map (clk100, savestate_bus, SAVESTATE_mixed_out , SAVESTATE_mixed_in);
   
   SAVESTATE_mixed_out(0) <= halt;           
   SAVESTATE_mixed_out(1) <= Flag_Zero;     
   SAVESTATE_mixed_out(2) <= Flag_Carry;     
   SAVESTATE_mixed_out(3) <= Flag_Negative;  
   SAVESTATE_mixed_out(4) <= Flag_V_Overflow;
   SAVESTATE_mixed_out(5) <= thumbmode;      
   SAVESTATE_mixed_out(9 downto 6) <= cpu_mode;       
   SAVESTATE_mixed_out(10) <= IRQ_disable;    
   SAVESTATE_mixed_out(11) <= FIQ_disable; 

   SAVESTATE_HALT            <= SAVESTATE_mixed_in(0);
   SAVESTATE_Flag_Zero       <= SAVESTATE_mixed_in(1);
   SAVESTATE_Flag_Carry      <= SAVESTATE_mixed_in(2);
   SAVESTATE_Flag_Negative   <= SAVESTATE_mixed_in(3);
   SAVESTATE_Flag_V_Overflow <= SAVESTATE_mixed_in(4);
   SAVESTATE_thumbmode       <= SAVESTATE_mixed_in(5);
   SAVESTATE_cpu_mode        <= SAVESTATE_mixed_in(9 downto 6);
   SAVESTATE_IRQ_disable     <= SAVESTATE_mixed_in(10);
   SAVESTATE_FIQ_disable     <= SAVESTATE_mixed_in(11);
   
   -- savestates
   
   gb_bus_Adr <= bus_fetch_Adr  when fetch_ack = '1' else bus_execute_Adr;
   gb_bus_rnw <= bus_fetch_rnw  when fetch_ack = '1' else bus_execute_rnw;
   gb_bus_ena <= '1'            when fetch_ack = '1' else bus_execute_ena;
   gb_bus_acc <= bus_fetch_acc  when fetch_ack = '1' else bus_execute_acc;
   
   PC_in_BIOS <= '1' when bus_fetch_Adr(27 downto 24) = x"0" else '0';
   jump_out   <= jump;

   process (clk100) 
      variable execute_skip : std_logic;
   begin
      if rising_edge(clk100) then
      
         done             <= '0';
         
         execute_start    <= '0';
         new_cycles_valid <= '0';
         
         if (dma_on = '1' and fetch_available = '1' and state_decode = DECODE_DONE and state_execute = FETCH_OP and jump = '0') then
            CPU_bus_idle <= '1';
         else
            CPU_bus_idle <= '0';
         end if;
            
         if (reset = '1') then -- reset
            
            -- ############# arm
            
            for i in 0 to 17 loop 
               regs(i) <= unsigned(SAVESTATE_REGS(i));
            end loop;
            
            regs_0_8  <= unsigned(SAVESTATE_REGS_0_8 );
            regs_0_9  <= unsigned(SAVESTATE_REGS_0_9 );
            regs_0_10 <= unsigned(SAVESTATE_REGS_0_10);
            regs_0_11 <= unsigned(SAVESTATE_REGS_0_11);
            regs_0_12 <= unsigned(SAVESTATE_REGS_0_12);
            regs_0_13 <= unsigned(SAVESTATE_REGS_0_13);
            regs_0_14 <= unsigned(SAVESTATE_REGS_0_14);
            regs_1_8  <= unsigned(SAVESTATE_REGS_1_8 );
            regs_1_9  <= unsigned(SAVESTATE_REGS_1_9 );
            regs_1_10 <= unsigned(SAVESTATE_REGS_1_10);
            regs_1_11 <= unsigned(SAVESTATE_REGS_1_11);
            regs_1_12 <= unsigned(SAVESTATE_REGS_1_12);
            regs_1_13 <= unsigned(SAVESTATE_REGS_1_13);
            regs_1_14 <= unsigned(SAVESTATE_REGS_1_14);
            regs_1_17 <= unsigned(SAVESTATE_REGS_1_17);
            regs_2_13 <= unsigned(SAVESTATE_REGS_2_13);
            regs_2_14 <= unsigned(SAVESTATE_REGS_2_14);
            regs_2_17 <= unsigned(SAVESTATE_REGS_2_17);
            regs_3_13 <= unsigned(SAVESTATE_REGS_3_13);
            regs_3_14 <= unsigned(SAVESTATE_REGS_3_14);
            regs_3_17 <= unsigned(SAVESTATE_REGS_3_17);
            regs_4_13 <= unsigned(SAVESTATE_REGS_4_13);
            regs_4_14 <= unsigned(SAVESTATE_REGS_4_14);
            regs_4_17 <= unsigned(SAVESTATE_REGS_4_17);
            regs_5_13 <= unsigned(SAVESTATE_REGS_5_13);
            regs_5_14 <= unsigned(SAVESTATE_REGS_5_14);
            regs_5_17 <= unsigned(SAVESTATE_REGS_5_17);
            
            PC <= unsigned(SAVESTATE_PC);

            halt <= SAVESTATE_HALT;
            
            -- ################ internal
               
            fetch_ack          <= '0';
            wait_fetch         <= '0';
            skip_pending_fetch <= '0';
            fetch_available    <= '0';
                
            decode_request     <= '1';
            state_decode       <= WAITFETCH;
                
            state_execute      <= FETCH_OP;
            
            -- only required for simulation, to test if e.g. drawing works, the cpu must run without doing anything
            if (is_simu = '1') then
            
               lastread           <= x"DEADDEAD"; -- for testing purpose only
            
               if (do_step = '1') then 
                  if (halt_cnt < 5) then
                     halt_cnt <= halt_cnt + 1;
                  else
                     halt_cnt <= 0;
                     new_cycles_valid <= '1';
                     new_cycles_out   <= to_unsigned(6, 8);
                  end if;
               end if;
            end if;
            
         elsif (gb_on = '1') then
         
            -- ############################
            -- Fetch
            -- ############################
            
            fetch_ack <= '0';
            
            if (jump = '1') then
               fetch_available    <= '0';
               skip_pending_fetch <= wait_fetch and not gb_bus_done;
               wait_fetch         <= '0';
               PC                 <= new_pc;
               
               if (wait_fetch = '0' or gb_bus_done = '1') then
                  bus_fetch_Adr <= std_logic_vector(new_pc);
                  bus_fetch_rnw <= '1';
                  if (thumbmode = '1') then 
                     bus_fetch_acc <= ACCESS_16BIT; 
                     PC            <= new_pc + 2;
                  else 
                     bus_fetch_acc <= ACCESS_32BIT; 
                     PC            <= new_pc + 4;
                  end if;
                  fetch_ack  <= '1';
                  wait_fetch <= '1';
               end if;
            else
            
               if (gb_bus_done = '1' and wait_fetch = '1') then
                  wait_fetch <= '0';
                  if (decode_request = '0') then
                     fetch_available <= '1';
                     fetch_data      <= gb_bus_din;
                     
                     --For THUMB code in 32K - WRAM on GBA, GBA SP, GBA Micro, NDS-Lite(but not NDS):
                     --LSW = [$+4], MSW = OldHI   ; for opcodes at 4 - byte aligned locations
                     --LSW = OldLO, MSW = [$+4]   ; for opcodes at non - 4 - byte aligned locations
                     --OldLO=[$+2], OldHI=[$+2]
                     
                     if (thumbmode = '1') then
                        if (PC(27 downto 24) = x"3") then
                           if (PC(1) = '0') then
                              lastread(31 downto 16) <= gb_bus_din(15 downto 0);
                           else
                              lastread(15 downto 0) <= gb_bus_din(15 downto 0);
                           end if;
                        else
                           lastread <= gb_bus_din(15 downto 0) & gb_bus_din(15 downto 0); -- standard case LSW = [$+4], MSW = [$+4]
                        end if;
                     else
                        lastread <= gb_bus_din;
                     end if;
                  end if;
               end if;
            
               if (executebus = '0') then
                  if ((fetch_available = '0' or decode_request = '1') and (wait_fetch = '0' or (gb_bus_done = '1' and decode_request = '1')) and (skip_pending_fetch = '0' or gb_bus_done = '1')) then
                     bus_fetch_Adr <= std_logic_vector(PC);
                     bus_fetch_rnw <= '1';
                     if (thumbmode = '1') then 
                        bus_fetch_acc <= ACCESS_16BIT; 
                        PC            <= PC + 2;
                     else 
                        bus_fetch_acc <= ACCESS_32BIT; 
                        PC            <= PC + 4;
                     end if;
                     fetch_ack  <= '1';
                     wait_fetch <= '1';
                  end if;
               end if;

               if (gb_bus_done = '1' and skip_pending_fetch = '1') then
                  skip_pending_fetch <= '0';
               end if;  
               
               if (fetch_available = '1' and decode_request = '1') then
                  fetch_available <= '0';
               end if;
               
            end if;
            
            -- ############################
            -- Decode
            -- ############################
            
            nextOpCodeAccessSeq16 <= 1 + memoryWaitSeq16(to_integer(unsigned(PC(27 downto 24))));
            nextOpCodeAccessSeq32 <= 1 + memoryWaitSeq32(to_integer(unsigned(PC(27 downto 24))));
            
            if (jump = '1') then
            
               state_decode   <= WAITFETCH;
               decode_request <= '1';
            
            else
            
               case state_decode is
               
                  when WAITFETCH =>
                     if (fetch_available = '1' or (gb_bus_done = '1' and skip_pending_fetch = '0' and wait_fetch = '1')) then
                        if (fetch_available = '1') then
                           decode_data   <= fetch_data;
                           decode_PC     <= PC;
                        else
                           decode_data <= gb_bus_din;
                           decode_PC   <= PC;
                        end if;
                        
                        if (thumbmode = '1') then
                           decode_cycles  <= nextOpCodeAccessSeq16;
                        else
                           decode_cycles  <= nextOpCodeAccessSeq32;
                        end if;
                        
                        state_decode   <= DECODE_DETAILS;
                        decode_request <= '0';
                     end if;
                  
                  when DECODE_DETAILS =>
                     state_decode   <= DECODE_DONE;
                     
                  when DECODE_DONE =>
                     if (state_execute = FETCH_OP and do_step = '1' and dma_on = '0' and settle = '0' and halt = '0') then
                        decode_request <= '1';
                        state_decode   <= WAITFETCH;
                     end if;
                  
               end case;
               
            end if;
            
            -- ############################
            -- Execute
            -- ############################
            
            if (new_halt = '1') then
               halt <= '1';
            end if;
            
            regs(16) <= Flag_Negative & Flag_Zero & Flag_Carry & Flag_V_Overflow & x"00000" & IRQ_disable & FIQ_disable & thumbmode & '1' & unsigned(cpu_mode);
            
            if (dma_init_cycles = '1') then
               new_cycles_out   <= to_unsigned(2, new_cycles_out'length);
               new_cycles_valid <= '1';
            end if;
            
            if (dma_new_cycles = '1') then
               new_cycles_valid <= '1';
               if (dma_dword_cycles = '1') then
                  if (dma_first_cycles = '1') then
                     if (dma_toROM = '1') then
                        new_cycles_out   <= to_unsigned(3 + memoryWait32(to_integer(unsigned(dma_cycles_adrup))), new_cycles_out'length);
                     else
                        new_cycles_out   <= to_unsigned(1 + memoryWait32(to_integer(unsigned(dma_cycles_adrup))), new_cycles_out'length);
                     end if;
                  else
                     new_cycles_out   <= to_unsigned(1 + memoryWaitSeq32(to_integer(unsigned(dma_cycles_adrup))), new_cycles_out'length);
                  end if;
               else
                  if (dma_first_cycles = '1') then
                     if (dma_toROM = '1') then
                        new_cycles_out   <= to_unsigned(3 + memoryWait16(to_integer(unsigned(dma_cycles_adrup))), new_cycles_out'length);
                     else
                        new_cycles_out   <= to_unsigned(1 + memoryWait16(to_integer(unsigned(dma_cycles_adrup))), new_cycles_out'length);
                     end if;
                  else
                     new_cycles_out   <= to_unsigned(1 + memoryWaitSeq16(to_integer(unsigned(dma_cycles_adrup))), new_cycles_out'length);
                  end if;
               end if;
            end if;
            
            if (execute_writeback_calc = '1') then
               if (writeback_reg /= x"F") then
                  regs(to_integer(unsigned(writeback_reg))) <= calc_result;
               end if;   
            end if;
            if (execute_writeback_r17 = '1') then
               regs(17) <= msr_writebackvalue;
            end if;
            if (execute_writeback_userreg = '1') then
               case (to_integer(unsigned(writeback_reg))) is
                  when 8  => regs_0_8  <= calc_result;
                  when 9  => regs_0_9  <= calc_result;
                  when 10 => regs_0_10 <= calc_result;
                  when 11 => regs_0_11 <= calc_result;
                  when 12 => regs_0_12 <= calc_result;
                  when 13 => regs_0_13 <= calc_result;
                  when 14 => regs_0_14 <= calc_result;
                  when others => null; -- does happen in armwrestler test
               end case;
            end if;
            
            if (execute_saveregs = '1') then
                     
               case (cpu_mode_old) is
                  when CPUMODE_USER | CPUMODE_SYSTEM =>
                     if (cpu_mode = CPUMODE_FIQ) then
                        regs_0_8  <= regs(8);
                        regs_0_9  <= regs(9);
                        regs_0_10 <= regs(10);
                        regs_0_11 <= regs(11);
                        regs_0_12 <= regs(12);
                     end if;
                     regs_0_13 <= regs(13);
                     regs_0_14 <= regs(14);
                     regs(17)  <= regs(16);
  
                  when CPUMODE_FIQ =>
                     regs_1_8  <= regs(8);
                     regs_1_9  <= regs(9);
                     regs_1_10 <= regs(10);
                     regs_1_11 <= regs(11);
                     regs_1_12 <= regs(12);
                     regs_1_13 <= regs(13);
                     regs_1_14 <= regs(14);
                     regs_1_17 <= regs(17);

                  when CPUMODE_IRQ =>
                     regs_2_13 <= regs(13);
                     regs_2_14 <= regs(14);
                     regs_2_17 <= regs(17);

                  when CPUMODE_SUPERVISOR =>
                     regs_3_13 <= regs(13);
                     regs_3_14 <= regs(14);
                     regs_3_17 <= regs(17);

                  when CPUMODE_ABORT =>
                     regs_4_13 <= regs(13);
                     regs_4_14 <= regs(14);
                     regs_4_17 <= regs(17);

                  when CPUMODE_UNDEFINED =>
                     regs_5_13 <= regs(13);
                     regs_5_14 <= regs(14);
                     regs_5_17 <= regs(17);
                     
                  when others => report "should never happen" severity failure; 
               end case;
                  
            end if;
               
            if (execute_switchregs = '1') then
            
               case (cpu_mode) is
                  when CPUMODE_USER | CPUMODE_SYSTEM =>
                     if (cpu_mode_old = CPUMODE_FIQ) then
                        regs(8)  <= regs_0_8; 
                        regs(9)  <= regs_0_9; 
                        regs(10) <= regs_0_10;
                        regs(11) <= regs_0_11;
                        regs(12) <= regs_0_12;
                     end if;
                     regs(13) <= regs_0_13;
                     regs(14) <= regs_0_14;
  
                  when CPUMODE_FIQ =>
                     regs(8)  <= regs_1_8 ;
                     regs(9)  <= regs_1_9 ;
                     regs(10) <= regs_1_10;
                     regs(11) <= regs_1_11;
                     regs(12) <= regs_1_12;
                     regs(13) <= regs_1_13;
                     regs(14) <= regs_1_14;
                     if (execute_saveState = '1') then regs(17) <= regs(16); else regs(17) <= regs_1_17; end if;

                  when CPUMODE_IRQ =>
                     regs(13) <= regs_2_13;
                     if (execute_IRP = '0') then
                        regs(14) <= regs_2_14;
                     end if;
                     if (execute_saveState = '1') then regs(17) <= regs(16); else regs(17) <= regs_2_17; end if;

                  when CPUMODE_SUPERVISOR =>
                     regs(13) <= regs_3_13;
                     if (execute_SWI = '0') then
                        regs(14) <= regs_3_14;
                     end if;
                     if (execute_saveState = '1') then regs(17) <= regs(16); else regs(17) <= regs_3_17; end if;

                  when CPUMODE_ABORT =>
                     regs(13) <= regs_4_13;
                     regs(14) <= regs_4_14;
                     if (execute_saveState = '1') then regs(17) <= regs(16); else regs(17) <= regs_4_17; end if;

                  when CPUMODE_UNDEFINED =>
                     regs(13) <= regs_5_13;
                     regs(14) <= regs_5_14;
                     if (execute_saveState = '1') then regs(17) <= regs(16); else regs(17) <= regs_5_17; end if;
                     
                  when others => report "should never happen" severity failure; 
               end case;
            
            end if;
            
            if (cpu_IRP = '1' and IRQ_disable = '0' and irq_delay = 0 and irq_calc = '0' and irq_triggerhold = '0') then
               irq_delay <= 4;
            end if;
            
            if (irq_delay > 0 and new_cycles_valid = '1') then
               if ((irq_delay - to_integer(new_cycles_out)) > 0) then
                  irq_delay <= irq_delay - to_integer(new_cycles_out);
               else
                  irq_delay       <= 0;
                  irq_triggerhold <= '1';
               end if;
            end if;
            
            irq_calc <= '0';
            
            case state_execute is
               
               when FETCH_OP =>
                  if (irq_triggerhold = '1' and IRQ_disable = '0' and dma_on = '0' and settle = '0') then

                     if (state_decode /= WAITFETCH) then -- dont do irp when decode_PC has not been updated
                        halt            <= '0';
                        irq_calc        <= '1';
                        state_execute   <= CALC;
                        execute_cycles  <= 0;
                        irq_triggerhold <= '0';
                        
                        if (thumbmode = '1') then
                           execute_PCprev <= decode_PC - 2;
                        else
                           execute_PCprev <= decode_PC - 4;
                        end if;
                        
                     end if;
                     
                  elsif (halt = '1' and dma_on = '0' and settle = '0') then
                     
                     if (do_step = '1') then 
                        if (halt_cnt < 5) then
                           halt_cnt <= halt_cnt + 1;
                        else
                           halt_cnt <= 0;
                           new_cycles_valid <= '1';
                           new_cycles_out   <= to_unsigned(6, 8); -- do 6x halt-speed for unlocked
                        end if;
                     end if;

                  elsif (state_decode = DECODE_DONE and do_step = '1' and dma_on = '0' and settle = '0' and jump = '0') then
                  
                     execute_cycles <= 0;
                  
                     if (thumbmode = '1') then
                        regs(15)(decode_PC'left downto 0) <= decode_PC + 2;
                     else
                        regs(15)(decode_PC'left downto 0) <= decode_PC + 4;
                     end if;
                     regs_plus_12  <= decode_PC + 8; -- only used for data operation available in arm mode
                     if (thumbmode = '1') then
                        block_pc_next <= decode_PC + 4;
                     else
                        block_pc_next <= decode_PC + 8;
                     end if;
                  
                     execute_skip := '1';
                     case (decode_condition) is
                        when x"0" => if (Flag_Zero = '1')                                        then execute_skip := '0'; end if;
                        when x"1" => if (Flag_Zero = '0')                                        then execute_skip := '0'; end if;
                        when x"2" => if (Flag_Carry = '1')                                       then execute_skip := '0'; end if;
                        when x"3" => if (Flag_Carry = '0')                                       then execute_skip := '0'; end if;
                        when x"4" => if (Flag_Negative = '1')                                    then execute_skip := '0'; end if;
                        when x"5" => if (Flag_Negative = '0')                                    then execute_skip := '0'; end if;
                        when x"6" => if (Flag_V_Overflow = '1')                                  then execute_skip := '0'; end if;
                        when x"7" => if (Flag_V_Overflow = '0')                                  then execute_skip := '0'; end if;
                        when x"8" => if (Flag_Carry = '1' and Flag_Zero = '0')                   then execute_skip := '0'; end if;
                        when x"9" => if (Flag_Carry = '0' or Flag_Zero = '1')                    then execute_skip := '0'; end if;
                        when x"A" => if (Flag_Negative = Flag_V_Overflow)                        then execute_skip := '0'; end if;
                        when x"B" => if (Flag_Negative /= Flag_V_Overflow)                       then execute_skip := '0'; end if;
                        when x"C" => if (Flag_Zero = '0' and (Flag_Negative = Flag_V_Overflow))  then execute_skip := '0'; end if;
                        when x"D" => if (Flag_Zero = '1' or (Flag_Negative /= Flag_V_Overflow))  then execute_skip := '0'; end if;
                        when x"E" => execute_skip := '0';
                        when others => null;
                     end case;
                  
                     if (execute_skip = '1') then
                        done             <= '1';
                        state_execute    <= FETCH_OP;
                        new_cycles_out   <= to_unsigned(decode_cycles, new_cycles_out'length);
                        new_cycles_valid <= '1';
                     else
                        state_execute   <= CALC;
                        execute_start   <= '1';
                     end if;
                     
                     if (thumbmode = '1') then
                        execute_PCprev <= decode_PC - 2;
                     else
                        execute_PCprev <= decode_PC - 4;
                     end if;
                     
                     execute_PC                       <= decode_PC;
                     execute_functions_detail         <= decode_functions_detail;
                     execute_datareceivetype          <= decode_datareceivetype;
                     execute_clearbit1                <= decode_clearbit1;      
                     execute_rdest                    <= decode_rdest;      
                     execute_Rn_op1                   <= decode_Rn_op1;   
                     execute_RM_op2                   <= decode_RM_op2;     
                     execute_alu_use_immi             <= decode_alu_use_immi;    
                     execute_alu_use_shift            <= decode_alu_use_shift;   
                     execute_immidiate                <= decode_immidiate;  
                     execute_shiftsettings            <= decode_shiftsettings;  
                     execute_shiftcarry               <= decode_shiftcarry; 
                     execute_useoldcarry              <= decode_useoldcarry;
                     execute_updateflags              <= decode_updateflags;
                     execute_muladd                   <= decode_muladd;
                     execute_mul_signed               <= decode_mul_signed;
                     execute_mul_useadd               <= decode_mul_useadd;
                     execute_mul_long                 <= decode_mul_long;
                     execute_writeback                <= decode_writeback;  
                     execute_switch_op                <= decode_switch_op;  
                     execute_set_thumbmode            <= decode_set_thumbmode;  
                     execute_branch_usereg            <= decode_branch_usereg; 
                     execute_branch_link              <= decode_branch_link;
                     execute_branch_immi              <= decode_branch_immi;
                     execute_datatransfer_type        <= decode_datatransfer_type;   
                     execute_datatransfer_preadd      <= decode_datatransfer_preadd;   
                     execute_datatransfer_addup       <= decode_datatransfer_addup;    
                     execute_datatransfer_writeback   <= decode_datatransfer_writeback;
                     execute_datatransfer_addvalue    <= decode_datatransfer_addvalue; 
                     execute_datatransfer_shiftval    <= decode_datatransfer_shiftval; 
                     execute_datatransfer_regoffset   <= decode_datatransfer_regoffset; 
                     execute_datatransfer_swap        <= decode_datatransfer_swap; 
                     execute_block_usermoderegs       <= decode_block_usermoderegs; 
                     execute_block_switchmode         <= decode_block_switchmode; 
                     execute_block_addrmod            <= decode_block_addrmod; 
                     execute_block_endmod             <= decode_block_endmod; 
                     execute_block_addrmod_baseRlist  <= decode_block_addrmod_baseRlist; 
                     execute_block_reglist            <= decode_block_reglist; 
                     execute_block_emptylist          <= decode_block_emptylist; 
                     execute_psr_with_spsr            <= decode_psr_with_spsr; 
                     execute_leaveirp                 <= decode_leaveirp; 
                     execute_leaveirp_user            <= decode_leaveirp_user; 
                     
                  end if;
               
               when CALC =>
               
                  if ((execute_writeback_calc = '0' or writeback_reg /= x"F") and calc_done = '1' and branchnext = '0') then
                     state_execute <= FETCH_OP;
                     done             <= '1';
                     new_cycles_out   <= to_unsigned(execute_cycles + execute_addcycles, new_cycles_out'length);
                     new_cycles_valid <= '1';
                  end if;
                 
                  execute_cycles <= execute_cycles + execute_addcycles;
               
            end case;
         

         end if;
      end if;
   end process;
   
   
   -- decoding function
   process (clk100) 
      variable opcode_high3      : std_logic_vector(2 downto 0);
      variable opcode_mid        : std_logic_vector(3 downto 0);
      variable opcode_low        : std_logic_vector(3 downto 0);
      variable bitcount8_low     : integer range 0 to 8;
      variable bitcount8_high    : integer range 0 to 8;
      
      variable decode_functions  : tFunctions;
      variable decode_datacomb   : std_logic_vector(27 downto 0) := (others => '0');
      
      -- decoding details
      variable opcode       : std_logic_vector(3 downto 0);
      variable use_imm      : std_logic;
      variable updateflags  : std_logic;
      variable Rn_op1       : std_logic_vector(3 downto 0);
      variable Rdest        : std_logic_vector(3 downto 0);
      variable RM_op2       : std_logic_vector(3 downto 0);
      variable OP2          : std_logic_vector(11 downto 0);
      
      variable rotateamount  : unsigned(4 downto 0);
      variable immidiate    : unsigned(31 downto 0);
      variable shiftcarry   : std_logic;
      variable useoldcarry  : std_logic;

   begin
   
      if (rising_edge(clk100)) then
   
         decode_datacomb  := decode_data(27 downto 0);
         
         decode_clearbit1 <= '0';
         
         bitcount8_low  := 0;
         bitcount8_high := 0;
         for i in 0 to 7 loop
            if (decode_data(i) = '1')     then bitcount8_low  := bitcount8_low + 1;  end if;
            if (decode_data(8 + i) = '1') then bitcount8_high := bitcount8_high + 1; end if;
         end loop;
   
         if (thumbmode = '0') then
         
            decode_condition <= decode_data(31 downto 28);

            opcode_high3  := decode_data(27 downto 25);
            opcode_mid    := decode_data(24 downto 21);
            opcode_low    := decode_data(7 downto 4);
   
            case (to_integer(unsigned(opcode_high3))) is
            
               when 0 => -- (27..25) = 000 => alu commands?
                  case (opcode_low) is
   
                     when x"1" =>
                        if (decode_data(24 downto 8) = '1' & x"2FFF") then
                           decode_functions := branch_and_exchange;
                           --branch_and_exchange(RM_op2);
                        else
                           decode_functions := data_processing;
                           --data_processing(use_imm, opcode_mid, updateflags, Rn_op1, Rdest, OP2, asmcmd);
                        end if;
   
                     when x"9" =>
                        if (unsigned(opcode_mid) >= 8) then
                           decode_functions := single_data_swap;
                           --single_data_swap((opcode_mid & 2) == 2, Rn_op1, Rdest, OP2);
                        elsif (unsigned(opcode_mid) >= 4) then
                           decode_functions := multiply_long;
                           --multiply_long(opcode_mid, updateflags, Rn_op1, Rdest, OP2);
                        else
                           decode_functions := multiply;
                           --multiply(opcode_mid, updateflags, Rdest, Rn_op1, (byte)((OP2 >> 8) & 0xF), (byte)(OP2 & 0xF));
                        end if;
   
                     when x"B" | x"D" | x"F" =>  -- halfword data transfer
                        if (decode_data(22) = '1') then --  immidiate offset
                           decode_functions := halfword_data_transfer_immoffset;
                           --halfword_data_transfer(opcode_mid, opcode_low, updateflags, Rn_op1, Rdest, (UInt32)(((OP2 >> 4) & 0xF0) | RM_op2));
                        else -- register offset
                           decode_functions := halfword_data_transfer_regoffset;
                           --halfword_data_transfer(opcode_mid, opcode_low, updateflags, Rn_op1, Rdest, regs[RM_op2]);
                        end if;
   
                     when others =>
                        decode_functions := data_processing;
                        --data_processing(use_imm, opcode_mid, updateflags, Rn_op1, Rdest, OP2, asmcmd);
   
                  end case;
   
               when 1 =>
                  decode_functions := data_processing;
                  --data_processing(use_imm, opcode_mid, updateflags, Rn_op1, Rdest, OP2, asmcmd);
   
               when 2 | 3 =>
                  decode_functions := single_data_transfer;
                  --single_data_transfer(use_imm, opcode_mid, opcode_low, updateflags, Rn_op1, Rdest, OP2);
   
               when 4 => 
                  decode_functions := block_data_transfer;
                  --block_data_transfer(opcode_mid, updateflags, Rn_op1, (UInt16)asmcmd);
   
               when 5 =>
                  decode_functions := branch;
                  --branch((opcode_mid & 8) == 8, asmcmd & 0xFFFFFF);
   
               when 7 =>
                  decode_functions := software_interrupt;
                  --software_interrupt();
            
               when others => report "should never happen" severity failure; 
            
            end case;
            
         else  -- thumb
         
            decode_condition <= x"E";
         
            case (to_integer(unsigned(decode_data(15 downto 13)))) is
         
               when 0 => 
                  if (decode_data(12 downto 11) = "11") then
                     decode_datacomb(27 downto 26)  := "00"; -- fixed
                     decode_datacomb(25)            := decode_data(10);  -- Immidiate
                     if (decode_data(9) = '1') then
                        decode_datacomb(24 downto 21)  := x"2"; -- Opcode -> sub
                     else
                        decode_datacomb(24 downto 21)  := x"4"; -- Opcode -> add
                     end if;
                     decode_datacomb(20)            := '1'; -- set condition codes
                     decode_datacomb(19 downto 16)  := '0' & decode_data(5 downto 3); -- RN -> 1st op
                     decode_datacomb(15 downto 12)  := '0' & decode_data(2 downto 0); -- Rdest
                     if (decode_data(10) = '1') then
                        decode_datacomb(11 downto  0)  := x"00" & '0' & decode_data(8 downto 6); -- 3 bit immidiate, no rotate
                     else
                        decode_datacomb(11 downto  4)  := x"00"; -- don't shift
                        decode_datacomb( 3 downto  0)  := '0' & decode_data(8 downto 6); -- Rm -> 2nd OP
                     end if;
                     decode_functions := data_processing;
                     --add_subtract(((asmcmd >> 10) & 1) == 1, ((asmcmd >> 9) & 1) == 1, (byte)((asmcmd >> 6) & 0x7), (byte)((asmcmd >> 3) & 0x7), (byte)(asmcmd & 0x7));
                  else
                     decode_datacomb(27 downto 26)  := "00"; -- fixed
                     decode_datacomb(25)            := '0';  -- Immidiate
                     decode_datacomb(24 downto 21)  := x"D"; -- Opcode -> mov
                     decode_datacomb(20)            := '1'; -- set condition codes
                     decode_datacomb(19 downto 16)  := x"0"; -- RN -> 1st op
                     decode_datacomb(15 downto 12)  := '0' & decode_data(2 downto 0); -- Rdest
                     decode_datacomb(11 downto  7)  := decode_data(10 downto 6);  -- shift amount
                     decode_datacomb( 6 downto  5)  := decode_data(12 downto 11); -- shift type
                     decode_datacomb( 4)            := '0';  -- shift with immidiate
                     decode_datacomb( 3 downto  0)  := '0' & decode_data(5 downto 3); -- Rm -> 2nd OP
                     decode_functions := data_processing;
                     --move_shifted_register((byte)((asmcmd >> 11) & 3), (byte)((asmcmd >> 6) & 0x1F), (byte)((asmcmd >> 3) & 0x7), (byte)(asmcmd & 0x7));
                  end if;
               
               when 1 =>
                  decode_datacomb(27 downto 26)  := "00"; -- fixed
                  decode_datacomb(25)            := '1';  -- Immidiate
                  case (decode_data(12 downto 11)) is
                     when "00" => decode_datacomb(24 downto 21)  := x"D"; -- Opcode -> mov
                     when "01" => decode_datacomb(24 downto 21)  := x"A"; -- Opcode -> cmp
                     when "10" => decode_datacomb(24 downto 21)  := x"4"; -- Opcode -> add
                     when "11" => decode_datacomb(24 downto 21)  := x"2"; -- Opcode -> sub
                     when others => report "should never happen" severity failure;
                  end case;
                  decode_datacomb(20)            := '1'; -- set condition codes
                  decode_datacomb(19 downto 16)  := '0' & decode_data(10 downto 8); -- RN -> 1st op
                  decode_datacomb(15 downto 12)  := '0' & decode_data(10 downto 8); -- Rdest
                  decode_datacomb(11 downto  0)  := x"0" & decode_data(7 downto 0); -- 8 bit immidiate, no rotate
                  decode_functions := data_processing;
                  --move_compare_add_subtract_immediate((byte)((asmcmd >> 11) & 3), (byte)((asmcmd >> 8) & 7), (byte)(asmcmd & 0xFF));
         
               when 2 =>
                  case (to_integer(unsigned(decode_data(12 downto 10)))) is
                     
                     when 0 =>
                        decode_datacomb(27 downto 26)  := "00"; -- fixed
                        decode_datacomb(25)            := '0';  -- Immidiate
                        decode_datacomb(20)            := '1'; -- set condition codes
                        decode_datacomb(19 downto 16)  := '0' & decode_data(2 downto 0); -- RN -> 1st op
                        decode_datacomb(15 downto 12)  := '0' & decode_data(2 downto 0); -- Rdest
                        decode_datacomb(11 downto  0)  := x"00" & '0' & decode_data(5 downto 3); -- RS -> 2nd OP -> no shift using op2 is default
                        decode_functions := data_processing;
                        case (decode_data(9 downto 6)) is
                           when x"0" => decode_datacomb(24 downto 21)  := x"0"; -- 0000 AND Rd, Rs ANDS Rd, Rd, Rs Rd:= Rd AND Rs
                           when x"1" => decode_datacomb(24 downto 21)  := x"1"; -- 0001 EOR Rd, Rs EORS Rd, Rd, Rs Rd:= Rd EOR Rs
                           
                           when x"2" =>                                         -- 0010 LSL Rd, Rs MOVS Rd, Rd, LSL Rs Rd := Rd << Rs
                              decode_datacomb(24 downto 21)  := x"D"; 
                              decode_datacomb(11 downto  0)  := '0' & decode_data(5 downto 3) & "0001" & '0' & decode_data(2 downto 0);
                           
                           when x"3" =>                                         -- 0011 LSR Rd, Rs MOVS Rd, Rd, LSR Rs Rd := Rd >> Rs
                              decode_datacomb(24 downto 21)  := x"D"; 
                              decode_datacomb(11 downto  0)  := '0' & decode_data(5 downto 3) & "0011" & '0' & decode_data(2 downto 0);
                              
                           when x"4" =>                                         -- 0100 ASR Rd, Rs MOVS Rd, Rd, ASR Rs Rd := Rd ASR Rs
                              decode_datacomb(24 downto 21)  := x"D"; 
                              decode_datacomb(11 downto  0)  := '0' & decode_data(5 downto 3) & "0101" & '0' & decode_data(2 downto 0);
                              
                           when x"5" => decode_datacomb(24 downto 21)  := x"5"; -- 0101 ADC Rd, Rs ADCS Rd, Rd, Rs Rd:= Rd + Rs + C - bit
                           when x"6" => decode_datacomb(24 downto 21)  := x"6"; -- 0110 SBC Rd, Rs SBCS Rd, Rd, Rs Rd:= Rd - Rs - NOT C - bit
                           
                           when x"7" =>                                         -- 0111 ROR Rd, Rs MOVS Rd, Rd, ROR Rs Rd := Rd ROR Rs
                              decode_datacomb(24 downto 21)  := x"D"; 
                              decode_datacomb(11 downto  0)  := '0' & decode_data(5 downto 3) & "0111" & '0' & decode_data(2 downto 0);                              
              
                           when x"8" => decode_datacomb(24 downto 21)  := x"8"; -- 1000 TST Rd, Rs TST Rd, Rs Set condition codes on Rd AND Rs
                           
                           when x"9" =>                                         -- 1001 NEG Rd, Rs RSBS Rd, Rs, #0 Rd = -Rs
                              decode_datacomb(24 downto 21)  := x"3"; 
                              decode_datacomb(25)            := '1';  -- Immidiate
                              decode_datacomb(11 downto  0)  := x"000";
                              decode_datacomb(19 downto 16)  := '0' & decode_data(5 downto 3); -- RS as 1st op
                              
                           when x"A" => decode_datacomb(24 downto 21)  := x"A"; -- 1010 CMP Rd, Rs CMP Rd, Rs Set condition codes on Rd - Rs
                           when x"B" => decode_datacomb(24 downto 21)  := x"B"; -- 1011 CMN Rd, Rs CMN Rd, Rs Set condition codes on Rd + Rs
                           when x"C" => decode_datacomb(24 downto 21)  := x"C"; -- 1100 ORR Rd, Rs ORRS Rd, Rd, Rs Rd:= Rd OR Rs
                           
                           when x"D" =>                                      -- 1101 MUL Rd, Rs MULS Rd, Rs, Rd Rd:= Rs * Rd
                              decode_datacomb(27 downto 20)  := x"01"; -- fixed 
                              decode_datacomb( 7 downto  4)  := x"9";  -- fixed 
                              decode_datacomb(11 downto  8)  := '0' & decode_data(2 downto 0); -- multiplier
                              decode_functions := multiply;
                              
                           when x"E" => decode_datacomb(24 downto 21)  := x"E"; -- 1110 BIC Rd, Rs BICS Rd, Rd, Rs Rd:= Rd AND NOT Rs
                           when x"F" => decode_datacomb(24 downto 21)  := x"F"; -- 1111 MVN Rd, Rs MVNS Rd, Rs Rd:= NOT Rs
                           when others => report "should never happen" severity failure;
                        end case;
                        
                        --alu_operations((byte)((asmcmd >> 6) & 0xF), (byte)((asmcmd >> 3) & 0x7), (byte)(asmcmd & 0x7));
                      
                     when 1 =>
                        decode_datacomb(27 downto 26)  := "00"; -- fixed
                        decode_datacomb(25)            := '0';  -- Immidiate
                        decode_datacomb(20)            := '0'; -- set condition codes
                        decode_datacomb(19 downto 16)  := '0' & decode_data(2 downto 0); -- RN -> 1st op
                        decode_datacomb(15 downto 12)  := '0' & decode_data(2 downto 0); -- Rdest
                        decode_datacomb(11 downto  0)  := x"00" & '0' & decode_data(5 downto 3); -- RS -> 2nd OP -> no shift using op2 is default
                        decode_functions               := data_processing;
                        case (decode_data(9 downto 6)) is
                           when x"1" => decode_datacomb(24 downto 21) := x"4"; decode_datacomb( 3) := '1';                                                         -- 0001 ADD Rd, Hs ADD Rd, Rd, Hs Add a register in the range 8 - 15 to a register in the range 0 - 7.
                           when x"2" => decode_datacomb(24 downto 21) := x"4"; decode_datacomb(19) := '1'; decode_datacomb(15) := '1';                             -- 0010 ADD Hd, Rs ADD Hd, Hd, Rs Add a register in the range 0 - 7 to a register in the range 8 - 15.
                           when x"3" => decode_datacomb(24 downto 21) := x"4"; decode_datacomb( 3) := '1'; decode_datacomb(19) := '1'; decode_datacomb(15) := '1'; -- 0011 ADD Hd, Hs ADD Hd, Hd, Hs Add two registers in the range 8 - 15
                                                                                
                           when x"5" => decode_datacomb(24 downto 21) := x"A"; decode_datacomb( 3) := '1';                                                         decode_datacomb(20) := '1'; -- 0101 CMP Rd, Hs CMP Rd, Hs Compare a register in the range 0 - 7 with a register in the range 8 - 15.Set the condition code flags on the result.
                           when x"6" => decode_datacomb(24 downto 21) := x"A"; decode_datacomb(19) := '1'; decode_datacomb(15) := '1';                             decode_datacomb(20) := '1'; -- 0110 CMP Hd, Rs CMP Hd, Rs Compare a register in the range 8 - 15 with a register in the range 0 - 7.Set the condition code flags on the result.
                           when x"7" => decode_datacomb(24 downto 21) := x"A"; decode_datacomb( 3) := '1'; decode_datacomb(19) := '1'; decode_datacomb(15) := '1'; decode_datacomb(20) := '1'; -- 0111 CMP Hd, Hs CMP Hd, Hs Compare two registers in the range 8 - 15.Set the condition code flags on the result.
                                                                                                                                                                   
                           when x"8" => decode_datacomb(24 downto 21) := x"D";                                                                                     -- 1000 -> undefined but probably just using low for both  
                           when x"9" => decode_datacomb(24 downto 21) := x"D"; decode_datacomb( 3) := '1';                                                         -- 1001 MOV Rd, Hs MOV Rd, Hs Move a value from a register in the range 8 - 15 to a register in the range 0 - 7.  
                           when x"A" => decode_datacomb(24 downto 21) := x"D"; decode_datacomb(19) := '1'; decode_datacomb(15) := '1';                             -- 1010 MOV Hd, Rs MOV Hd, Rs Move a value from a register in the range 0 - 7 to a register in the range 8 - 15.
                           when x"B" => decode_datacomb(24 downto 21) := x"D"; decode_datacomb( 3) := '1'; decode_datacomb(19) := '1'; decode_datacomb(15) := '1'; -- 1011 MOV Hd, Hs MOV Hd, Hs Move a value between two registers in the range 8 - 15.
                                                                               
                           when x"C" => decode_functions := branch_and_exchange;                               -- 1100 BX Rs Perform branch(plus optional state change) to address in a register in the range 0 - 7.
                           when x"D" => decode_functions := branch_and_exchange; decode_datacomb(3) := '1';  -- 1101 BX Hs Perform branch(plus optional state change) to address in a register in the range 8 - 15.

                           -- can't do this check, as prefetch may fetch data that could contain this
                           --when others => report "decode_data(12 downto 10) = 1 => case should never happen" severity failure;
                           when others => null;
                        end case;
                        
                        --hi_register_operations_branch_exchange((byte)((asmcmd >> 6) & 0xF), (byte)((asmcmd >> 3) & 0x7), (byte)(asmcmd & 0x7));   
               
                     when 2 | 3 =>
                        decode_datacomb(27 downto 26)  := "01"; -- fixed
                        decode_datacomb(25)            := '0';  -- offset is immidiate
                        decode_datacomb(24)            := '1';  -- pre add offset
                        decode_datacomb(23)            := '1';  -- add offset
                        decode_datacomb(22)            := '0';  -- word
                        decode_datacomb(21)            := '0';  -- writeback
                        decode_datacomb(20)            := decode_data(11); -- read/write
                        decode_datacomb(19 downto 16)  := x"F"; -- base register
                        decode_clearbit1               <= '1';
                        decode_datacomb(15 downto 12)  := '0' & decode_data(10 downto 8); -- Rdest
                        decode_datacomb(11 downto  0)  := "00" & decode_data(7 downto 0) & "00"; -- offset immidiate
                        decode_functions := single_data_transfer;
                        --pc_relative_load((byte)((asmcmd >> 8) & 0x7), (byte)(asmcmd & 0xFF));
                        
                     when 4 | 5 | 6 | 7 =>
                        if (decode_data(9) = '0') then
                           decode_datacomb(27 downto 26)  := "01"; -- fixed
                           decode_datacomb(25)            := '1';  -- offset is reg
                           decode_datacomb(24)            := '1';  -- pre add offset
                           decode_datacomb(23)            := '1';  -- add offset
                           decode_datacomb(22)            := decode_data(10);  -- byte/word
                           decode_datacomb(21)            := '0';  -- writeback
                           decode_datacomb(20)            := decode_data(11); -- read/write
                           decode_datacomb(19 downto 16)  := '0' & decode_data(5 downto 3); -- base register
                           decode_datacomb(15 downto 12)  := '0' & decode_data(2 downto 0); -- Rdest
                           decode_datacomb(11 downto  4)  := x"00"; -- don't shift
                           decode_datacomb( 3 downto  0)  := '0' & decode_data(8 downto 6); -- offset register
                           decode_functions := single_data_transfer;
                           --load_store_with_register_offset(((asmcmd >> 11) & 1) == 1, ((asmcmd >> 10) & 1) == 1, (byte)((asmcmd >> 6) & 0x7), (byte)((asmcmd >> 3) & 0x7), (byte)(asmcmd & 0x7));
                        else
                           decode_datacomb(27 downto 25)  := "000"; -- fixed
                           decode_datacomb(24)            := '1';  -- pre add offset
                           decode_datacomb(23)            := '1';  -- add offset
                           decode_datacomb(22)            := '1';  -- fixed
                           decode_datacomb(21)            := '0';  -- writeback
                           decode_datacomb(19 downto 16)  := '0' & decode_data(5 downto 3); -- base register
                           decode_datacomb(15 downto 12)  := '0' & decode_data(2 downto 0); -- Rdest
                           decode_datacomb(11 downto  8)  := "0000"; -- fixed
                           decode_datacomb( 7)            := '1'; -- fixed
                           decode_datacomb( 4)            := '1'; -- fixed
                           decode_datacomb( 3 downto  0)  := '0' & decode_data(8 downto 6); -- offset register
                           case (decode_data(11 downto 10)) is -- read     S                             H
                              when "00" => decode_datacomb(20) := '0'; decode_datacomb(6) := '0'; decode_datacomb(5) := '1'; -- Store halfword
                              when "01" => decode_datacomb(20) := '1'; decode_datacomb(6) := '1'; decode_datacomb(5) := '0'; -- Load sign-extended byte
                              when "10" => decode_datacomb(20) := '1'; decode_datacomb(6) := '0'; decode_datacomb(5) := '1'; -- Load halfword
                              when "11" => decode_datacomb(20) := '1'; decode_datacomb(6) := '1'; decode_datacomb(5) := '1'; -- Load sign-extended halfword
                              when others => null;  
                           end case;
                           decode_functions := halfword_data_transfer_regoffset;
                           --load_store_sign_extended_byte_halfword((byte)((asmcmd >> 10) & 0x3), (byte)((asmcmd >> 6) & 0x7), (byte)((asmcmd >> 3) & 0x7), (byte)(asmcmd & 0x7));
                        end if;
                        
                     when others => report "should never happen" severity failure;
               
                  end case;
               
               when 3 =>
                  decode_datacomb(27 downto 26)  := "01"; -- fixed
                  decode_datacomb(25)            := '0';  -- offset is reg
                  decode_datacomb(24)            := '1';  -- pre add offset
                  decode_datacomb(23)            := '1';  -- add offset
                  decode_datacomb(22)            := decode_data(12);  -- dword
                  decode_datacomb(21)            := '0';  -- writeback
                  decode_datacomb(20)            := decode_data(11); -- read/write
                  decode_datacomb(19 downto 16)  := '0' & decode_data(5 downto 3); -- base register
                  decode_datacomb(15 downto 12)  := '0' & decode_data(2 downto 0); -- Rdest
                  if (decode_data(12) = '1') then -- byte -> 5 bit address
                     decode_datacomb(11 downto  0)  := "0000000" & decode_data(10 downto 6); -- offset immidiate
                  else
                     decode_datacomb(11 downto  0)  := "00000" & decode_data(10 downto 6) & "00"; -- offset immidiate
                  end if;
                  decode_functions := single_data_transfer;
                  --load_store_with_immidiate_offset(((asmcmd >> 11) & 1) == 1, ((asmcmd >> 12) & 1) == 1, (byte)((asmcmd >> 6) & 0x1F), (byte)((asmcmd >> 3) & 0x7), (byte)(asmcmd & 0x7));
               
               when 4 =>
                  if (decode_data(12) = '0') then
                     decode_datacomb(27 downto 25)  := "000"; -- fixed
                     decode_datacomb(24)            := '1';  -- pre add offset
                     decode_datacomb(23)            := '1';  -- add offset
                     decode_datacomb(22)            := '1';  -- fixed
                     decode_datacomb(21)            := '0';  -- writeback
                     decode_datacomb(20)            := decode_data(11); -- read/write
                     decode_datacomb(19 downto 16)  := '0' & decode_data(5 downto 3); -- base register
                     decode_datacomb(15 downto 12)  := '0' & decode_data(2 downto 0); -- Rdest
                     decode_datacomb(11 downto  8)  := "00" & decode_data(10 downto 9); -- offset immidiate
                     decode_datacomb( 7)            := '1'; -- fixed
                     decode_datacomb( 6)            := '0'; -- S
                     decode_datacomb( 5)            := '1'; -- H
                     decode_datacomb( 4)            := '1'; -- fixed
                     decode_datacomb( 3 downto  0)  := decode_data(8 downto 6) & '0'; -- offset immidiate
                     decode_functions := halfword_data_transfer_immoffset;
                     --load_store_halfword(((asmcmd >> 11) & 1) == 1, (byte)((asmcmd >> 6) & 0x1F), (byte)((asmcmd >> 3) & 0x7), (byte)(asmcmd & 0x7));
                  else
                     decode_datacomb(27 downto 26)  := "01"; -- fixed
                     decode_datacomb(25)            := '0';  -- offset is reg
                     decode_datacomb(24)            := '1';  -- pre add offset
                     decode_datacomb(23)            := '1';  -- add offset
                     decode_datacomb(22)            := '0';  -- dword
                     decode_datacomb(21)            := '0';  -- writeback
                     decode_datacomb(20)            := decode_data(11); -- read/write
                     decode_datacomb(19 downto 16)  := x"D"; -- base register
                     decode_datacomb(15 downto 12)  := '0' & decode_data(10 downto 8); -- Rdest
                     decode_datacomb(11 downto  0)  := "00" & decode_data(7 downto 0) & "00"; -- offset immidiate
                     decode_functions := single_data_transfer;
                     --sp_relative_load_store(((asmcmd >> 11) & 1) == 1, (byte)((asmcmd >> 8) & 0x7), (byte)(asmcmd & 0xFF));
                  end if;
                  
               when 5 =>
                  if (decode_data(12) = '0') then
                     decode_datacomb(27 downto 26)  := "00"; -- fixed
                     decode_datacomb(25)            := '1';  -- Immidiate
                     decode_datacomb(24 downto 21)  := x"4"; -- Opcode -> add
                     decode_datacomb(20)            := '0';  -- set condition codes
                     if (decode_data(11) = '1') then -- stack pointer 13(1) or PC(15)
                        decode_datacomb(19 downto 16)  := x"D"; -- RN -> 1st op
                     else 
                        decode_datacomb(19 downto 16)  := x"F"; -- RN -> 1st op
                        decode_clearbit1               <= '1';
                     end if;
                     decode_datacomb(15 downto 12)  := '0' & decode_data(10 downto 8); -- Rdest
                     decode_datacomb(11 downto  0)  := x"F" & decode_data(7 downto 0); -- 8 bit immidiate, shift left by 2
                     decode_functions := data_processing;
                     --load_address(((asmcmd >> 11) & 1) == 1, (byte)((asmcmd >> 8) & 0x7), (byte)(asmcmd & 0xFF));
                  else
                     if (decode_data(10) = '0') then
                        decode_datacomb(27 downto 26)  := "00"; -- fixed
                        decode_datacomb(25)            := '1';  -- Immidiate
                        if (decode_data(7) = '1') then -- sign bit
                           decode_datacomb(24 downto 21)  := x"2"; -- Opcode -> sub
                        else 
                           decode_datacomb(24 downto 21)  := x"4"; -- Opcode -> add
                        end if;
                        decode_datacomb(20)            := '0'; -- set condition codes
                        decode_datacomb(19 downto 16)  := x"D"; -- RN -> 1st op
                        decode_datacomb(15 downto 12)  := x"D"; -- Rdest
                        decode_datacomb(11 downto  0)  := x"F" & '0' & decode_data(6 downto 0); -- 8 bit immidiate, shift left by 2
                        decode_functions := data_processing;
                        --add_offset_to_stack_pointer(((asmcmd >> 7) & 1) == 1, (byte)(asmcmd & 0x7F));
                     else
                        decode_datacomb(27 downto 25)  := "100"; -- fixed
                        decode_datacomb(22)            := '0'; -- PSR
                        decode_datacomb(21)            := '1'; -- Writeback
                        decode_datacomb(20)            := decode_data(11); -- Load
                        decode_datacomb(15 downto 0)   := x"00" & decode_data(7 downto 0); -- reglist
                        decode_datacomb(19 downto 16)  := x"D"; -- base register -> 13
                        bitcount8_high := 0;
                        if (decode_data(8) = '1') then -- link
                           bitcount8_high := 1;
                           if (decode_data(11) = '1') then -- load
                              decode_datacomb(15) := '1';
                           else
                              decode_datacomb(14) := '1';
                           end if;
                        end if;
                        -- LDMIA!  opcode = !pre up !csr store  <-> // STMDB !  opcode = pre !up !csr store
                        decode_datacomb(24) := not decode_data(11); -- Pre
                        decode_datacomb(23) := decode_data(11);     -- up
                        decode_functions := block_data_transfer;
                        --push_pop_register(((asmcmd >> 11) & 1) == 1, ((asmcmd >> 8) & 1) == 1, (byte)(asmcmd & 0xFF));
                     end if;
                  end if;
                  
               when 6 => 
                  if (decode_data(12) = '0') then
                     decode_datacomb(27 downto 25)  := "100"; -- fixed
                     decode_datacomb(24)            := '0'; -- Pre
                     decode_datacomb(23)            := '1'; -- up
                     decode_datacomb(22)            := '0'; -- PSR
                     decode_datacomb(21)            := '1'; -- Writeback
                     decode_datacomb(20)            := decode_data(11); -- Load
                     decode_datacomb(19 downto 16)  := '0' & decode_data(10 downto 8); -- base register
                     decode_datacomb(15 downto 0)   := x"00" & decode_data(7 downto 0); -- reglist
                     bitcount8_high                 := 0;
                     decode_functions               := block_data_transfer;
                     --multiple_load_store(((asmcmd >> 11) & 1) == 1, (byte)((asmcmd >> 8) & 0x7), (byte)(asmcmd & 0xFF));
                  else
                     if (decode_data(11 downto 8) = x"F") then
                        decode_functions := software_interrupt;
                        --software_interrupt();
                     else
                        decode_datacomb(27 downto 25) := "101"; -- fixed
                        decode_datacomb(24)           := '0';   -- without link
                        decode_datacomb(23 downto 0)  := std_logic_vector(resize(signed(decode_data(7 downto 0)), 24));
                        decode_condition              <= decode_data(11 downto 8);
                        decode_functions := branch;
                        --conditional_branch((byte)((asmcmd >> 8) & 0xF), (byte)(asmcmd & 0xFF));
                     end if;
                  end if;
                     
               when 7 =>
                  if (decode_data(12) = '0') then
                     decode_datacomb(27 downto 25) := "101"; -- fixed
                     decode_datacomb(24)           := '0';   -- without link
                     decode_datacomb(23 downto 0)  := std_logic_vector(resize(signed(decode_data(10 downto 0)), 24));
                     decode_functions := branch;
                     --unconditional_branch((UInt16)(asmcmd & 0x7FF));
                  else
                     decode_functions := long_branch_with_link;
                     --long_branch_with_link(((asmcmd >> 11) & 1) == 1, (UInt16)(asmcmd & 0x7FF));
                  end if;
               
               when others => report "should never happen" severity failure; 
         
            end case;
         
         end if;
   
      -- decoding details
   
         use_imm       := decode_datacomb(25);
         updateflags   := decode_datacomb(20);
         Rn_op1        := decode_datacomb(19 downto 16);
         Rdest         := decode_datacomb(15 downto 12);
         RM_op2        := decode_datacomb(3 downto 0);
         OP2           := decode_datacomb(11 downto 0);
         opcode        := decode_datacomb(24 downto 21);
      
         decode_updateflags            <= '1';
         decode_alu_use_immi           <= '0';
         decode_alu_use_shift          <= '0';
         decode_switch_op              <= '0';
         decode_datatransfer_shiftval  <= '0';
         decode_datatransfer_regoffset <= '0';
         decode_datatransfer_swap      <= '0';
         decode_datatransfer_writeback <= '0';
         decode_leaveirp               <= '0';
         decode_leaveirp_user          <= '0';
         
         decode_shiftsettings    <= decode_datacomb(11 downto 4);
   
         case (decode_functions) is 
            when data_processing =>
         
               -- imidiate calculation
               rotateamount := unsigned(Op2(11 downto 8)) & '0';
               immidiate   := x"000000" & unsigned(Op2(7 downto 0));
               
               useoldcarry := '0';
               shiftcarry  := '0';
               if (rotateamount = 0) then
                  useoldcarry := '1';
               else
                  shiftcarry  := immidiate(to_integer(rotateamount) - 1);
               end if;

               immidiate   := immidiate ror to_integer(rotateamount);
            
               decode_rdest            <= Rdest;
               decode_Rn_op1           <= Rn_op1;
               decode_RM_op2           <= RM_op2;
               decode_alu_use_immi     <= use_imm;
               decode_immidiate        <= immidiate;
               decode_shiftcarry       <= shiftcarry;
               decode_useoldcarry      <= useoldcarry;
               decode_updateflags      <= updateflags;

               decode_alu_use_immi     <= use_imm;
               decode_alu_use_shift    <= not use_imm;
            
               if (updateflags = '0' and unsigned(opcode) >= 8 and unsigned(opcode) <= 11) then -- PSR Transfer
            
                  decode_psr_with_spsr    <= decode_datacomb(22); -- spsr -> reg17
            
                  if (decode_datacomb(21 downto 16) = "001111") then 
                     decode_functions_detail <= data_processing_MRS; -- MRS (transfer PSR contents to a register)
                  else
                     decode_functions_detail <= data_processing_MSR; -- MSR (transfer register contents or immdiate value to PSR)
                  end if;
            
               else
               
                  case opcode is
                     when x"0" => decode_functions_detail <= alu_and;           decode_writeback <= '1'; decode_switch_op <= '0'; --  AND 0000 operand1 AND operand2
                     when x"1" => decode_functions_detail <= alu_xor;           decode_writeback <= '1'; decode_switch_op <= '0'; --  EOR 0001 operand1 EOR operand2
                     when x"2" => decode_functions_detail <= alu_sub;           decode_writeback <= '1'; decode_switch_op <= '0'; --  SUB 0010 operand1 - operand2
                     when x"3" => decode_functions_detail <= alu_sub;           decode_writeback <= '1'; decode_switch_op <= '1'; --  RSB 0011 operand2 - operand1
                     when x"4" => decode_functions_detail <= alu_add;           decode_writeback <= '1'; decode_switch_op <= '0'; --  ADD 0100 operand1 + operand2
                     when x"5" => decode_functions_detail <= alu_add_withcarry; decode_writeback <= '1'; decode_switch_op <= '0'; --  ADC 0101 operand1 + operand2 + carry
                     when x"6" => decode_functions_detail <= alu_sub_withcarry; decode_writeback <= '1'; decode_switch_op <= '0'; --  SBC 0110 operand1 - operand2 + carry - 1
                     when x"7" => decode_functions_detail <= alu_sub_withcarry; decode_writeback <= '1'; decode_switch_op <= '1'; --  RSC 0111 operand2 - operand1 + carry - 1
                     when x"8" => decode_functions_detail <= alu_and;           decode_writeback <= '0'; decode_switch_op <= '0'; --  TST 1000 as AND, but result is not written
                     when x"9" => decode_functions_detail <= alu_xor;           decode_writeback <= '0'; decode_switch_op <= '0'; --  TEQ 1001 as EOR, but result is not written
                     when x"A" => decode_functions_detail <= alu_sub;           decode_writeback <= '0'; decode_switch_op <= '0'; --  CMP 1010 as SUB, but result is not written
                     when x"B" => decode_functions_detail <= alu_add;           decode_writeback <= '0'; decode_switch_op <= '0'; --  CMN 1011 as ADD, but result is not written
                     when x"C" => decode_functions_detail <= alu_or;            decode_writeback <= '1'; decode_switch_op <= '0'; --  ORR 1100 operand1 OR operand2
                     when x"D" => decode_functions_detail <= alu_mov;           decode_writeback <= '1'; decode_switch_op <= '0'; --  MOV 1101 operand2(operand1 is ignored)
                     when x"E" => decode_functions_detail <= alu_and_not;       decode_writeback <= '1'; decode_switch_op <= '0'; --  BIC 1110 operand1 AND NOT operand2(Bit clear)
                     when x"F" => decode_functions_detail <= alu_mov_not;       decode_writeback <= '1'; decode_switch_op <= '0'; --  MVN 1111 NOT operand2(operand1 is ignored)
                     when others => report "should never happen" severity failure; 
                  end case;
                  
                  if (Rdest = x"F" and updateflags = '1') then
                     decode_leaveirp <= '1';
                     if (cpu_mode = CPUMODE_SYSTEM or cpu_mode = CPUMODE_USER) then
                        decode_leaveirp_user <= '1';
                        decode_updateflags   <= '0';
                     end if;
                  end if;
               
               end if;
               
            when multiply | multiply_long =>
               decode_functions_detail <= mulboth;
               decode_rdest            <= decode_datacomb(19 downto 16);
               decode_Rn_op1           <= decode_datacomb(3 downto 0);
               decode_RM_op2           <= decode_datacomb(11 downto 8);
               decode_updateflags      <= decode_datacomb(20);
               decode_muladd           <= decode_datacomb(15 downto 12);
               decode_mul_signed       <= decode_datacomb(22);
               decode_mul_useadd       <= decode_datacomb(21);
               decode_mul_long         <= '0';
               if (decode_functions = multiply_long) then
                  decode_mul_long <= '1';
               end if;
               
            when branch =>
               decode_functions_detail <= branch_all;
               decode_set_thumbmode    <= '0';
               decode_branch_link      <= decode_datacomb(24);
               if (thumbmode = '1') then
                  decode_branch_immi   <= resize(signed(decode_datacomb(23 downto 0)), 25) & "0";
               else
                  decode_branch_immi   <= signed(decode_datacomb(23 downto 0)) & "00";
               end if;
               decode_rdest            <= x"E"; -- 14
               decode_branch_usereg    <= '0';
            
            when branch_and_exchange =>
               decode_functions_detail <= branch_all;
               decode_set_thumbmode    <= '1';
               decode_RM_op2           <= RM_op2;
               decode_branch_usereg    <= '1';
               decode_branch_link      <= '0';
                            
            when single_data_transfer | halfword_data_transfer_regoffset | halfword_data_transfer_immoffset | single_data_swap => 
               if (decode_datacomb(20) = '1') then
                  decode_functions_detail <= data_read;
               else
                  decode_functions_detail <= data_write;
               end if;
               decode_RM_op2 <= RM_op2;
               decode_Rn_op1 <= Rn_op1;
               decode_rdest  <= Rdest;
               
               decode_datatransfer_preadd    <= opcode(3);
               decode_datatransfer_addup     <= opcode(2);
               decode_datatransfer_writeback <= (not opcode(3)) or opcode(0);
               if (Rn_op1 = Rdest and decode_datacomb(20) = '1') then --when storing, result address can be written
                  decode_datatransfer_writeback <= '0';
               end if;
               
               decode_datatransfer_shiftval  <= '0';
               decode_datatransfer_regoffset <= '0';
               decode_datatransfer_swap      <= '0';
               decode_datatransfer_addvalue  <= (others => '0');
               
               if (decode_functions = single_data_transfer) then
                  decode_datatransfer_addvalue  <= unsigned(op2);
                  decode_datatransfer_shiftval  <= use_imm;
                  decode_datatransfer_regoffset <= use_imm;
                  if (opcode(1) = '1') then
                     decode_datatransfer_type <= ACCESS_8BIT;
                     decode_datareceivetype   <= RECEIVETYPE_BYTE;
                  else
                     decode_datatransfer_type <= ACCESS_32BIT;
                     decode_datareceivetype   <= RECEIVETYPE_DWORD;
                  end if;
               elsif (decode_functions = halfword_data_transfer_regoffset or decode_functions = halfword_data_transfer_immoffset) then
                  case (decode_datacomb(6 downto 5)) is
                     when "01" => decode_datatransfer_type <= ACCESS_16BIT; decode_datareceivetype <= RECEIVETYPE_WORD;
                     when "10" => decode_datatransfer_type <= ACCESS_8BIT;  decode_datareceivetype <= RECEIVETYPE_SIGNEDBYTE;
                     when "11" => decode_datatransfer_type <= ACCESS_16BIT; decode_datareceivetype <= RECEIVETYPE_SIGNEDWORD;
                     when others => report "should never happen" severity failure;
                  end case;
                  decode_datatransfer_addvalue <= x"0" & unsigned(decode_datacomb(11 downto 8)) & unsigned(decode_datacomb(3 downto 0));
                  if (decode_functions = halfword_data_transfer_regoffset) then
                     decode_datatransfer_regoffset <= '1';
                  end if;
               elsif (decode_functions = single_data_swap) then
                  decode_datatransfer_writeback <= '0';
                  decode_functions_detail       <= data_read;
                  decode_datatransfer_swap      <= '1';
                  if (opcode(1) = '1') then
                     decode_datatransfer_type <= ACCESS_8BIT;
                     decode_datareceivetype   <= RECEIVETYPE_BYTE;
                  else
                     decode_datatransfer_type <= ACCESS_32BIT;
                     decode_datareceivetype   <= RECEIVETYPE_DWORD;
                  end if;
               end if;
            
            when block_data_transfer  => 
               if (decode_datacomb(20) = '1') then
                  decode_functions_detail <= block_read;
               else
                  decode_functions_detail <= block_write;
               end if;
               
               decode_Rn_op1                 <= Rn_op1;
               decode_block_reglist          <= decode_datacomb(15 downto 0);
               decode_datatransfer_preadd    <= opcode(3);
               decode_datatransfer_addup     <= opcode(2);
               decode_datatransfer_writeback <= opcode(0);
               if (decode_datacomb(to_integer(unsigned(Rn_op1))) = '1' and decode_datacomb(20) = '1') then -- writeback in reglist and load
                  decode_datatransfer_writeback <= '0';
               end if;
               if (decode_datacomb(15 downto 0) = x"0000") then -- reglist empty
                  decode_block_reglist(15) <= '1';
                  decode_block_emptylist   <= '1';
               else
                  decode_block_emptylist   <= '0';
               end if;
               
               decode_block_usermoderegs <= '0';
               decode_block_switchmode   <= '0';
               if (opcode(1) = '1') then
                  if ((decode_datacomb(15) = '1' and decode_datacomb(20) = '0') or (decode_datacomb(15) = '0')) then
                     decode_block_usermoderegs <= '1';
                  end if;
                  if (decode_datacomb(15) = '1' and decode_datacomb(20) = '1') then
                     decode_block_switchmode <= '1';
                  end if;
               end if;
               
               decode_block_addrmod <= 0;
               decode_block_endmod  <= 0;
               if (opcode(2) = '0') then -- down
                  if (decode_datacomb(15 downto 0) = x"0000") then -- reglist empty
                     decode_block_endmod  <= -64;
                     decode_block_addrmod <= -64;
                     if (opcode(3) = '0') then -- not pre
                        decode_block_addrmod <= -60;
                     end if;
                  else
                     decode_block_endmod <= (-4) * (bitcount8_low + bitcount8_high);
                     if (opcode(3) = '0') then -- not pre
                        decode_block_addrmod <= ((-4) * (bitcount8_low + bitcount8_high)) + 4;
                     else
                        decode_block_addrmod <= (-4) * (bitcount8_low + bitcount8_high);
                     end if;
                     decode_block_addrmod_baseRlist <= (-4) * (bitcount8_low + bitcount8_high);
                  end if;
               elsif (opcode(3) = '1') then -- pre
                  decode_block_addrmod <= 4;
               end if;
               if (opcode(2) = '1') then --up
                  decode_block_addrmod_baseRlist <= 4 * (bitcount8_low + bitcount8_high);
                  if (decode_datacomb(15 downto 0) = x"0000") then -- empty list
                     decode_block_endmod <= 64;
                  end if;
               end if;
               
            when software_interrupt => 
               decode_functions_detail <= software_interrupt_detail;
               decode_rdest            <= x"E"; -- 14
         
            -- thumb

            when long_branch_with_link => 
               if (decode_datacomb(11) = '0') then
                  decode_functions_detail <= alu_add;
                  decode_writeback        <= '1'; 
                  decode_rdest            <= x"E";
                  decode_Rn_op1           <= x"F";
                  decode_alu_use_immi     <= '1';
                  decode_updateflags      <= '0';
                  decode_immidiate        <= unsigned(resize(signed(decode_datacomb(10 downto 0)), 20)) & x"000";
               else
                  decode_functions_detail <= long_branch_with_link_low;
                  decode_immidiate        <= x"00000" & "0" & unsigned(decode_datacomb(10 downto 0));
               end if;
            
         end case;
         
         
      end if;
   
   end process;
   
   
   -- timing
   process (clk100) 
   begin
      if (rising_edge(clk100)) then
      
         wait_cnt_update_1 <= wait_cnt_update;
         
         if (gb_on = '0') then
         
            memoryWait16    <= (0, 0, 2, 0, 0, 0, 0, 0, 4, 4, 4, 4,  4,  4, 4, 0);
            memoryWait32    <= (0, 0, 5, 0, 0, 1, 1, 0, 7, 7, 9, 9, 13, 13, 4, 0);
            memoryWaitSeq16 <= (0, 0, 2, 0, 0, 0, 0, 0, 2, 2, 4, 4,  8,  8, 4, 0);
            memoryWaitSeq32 <= (0, 0, 5, 0, 0, 1, 1, 0, 5, 5, 9, 9, 17, 17, 4, 0);
            
            busPrefetchEnable <= '0';
            
         else
      
            if (wait_cnt_update = '1') then
               memoryWait16(14)    <= gamepakRamWaitState(to_integer(wait_cnt_value(1 downto 0)));
               memoryWaitSeq16(14) <= gamepakRamWaitState(to_integer(wait_cnt_value(1 downto 0)));
               
               memoryWait16(8)     <= gamepakWaitState(to_integer(wait_cnt_value(3 downto 2)));
               memoryWaitSeq16(8)  <= gamepakWaitState0(to_integer(wait_cnt_value(4 downto 4)));
               memoryWait16(9)     <= gamepakWaitState(to_integer(wait_cnt_value(3 downto 2)));
               memoryWaitSeq16(9)  <= gamepakWaitState0(to_integer(wait_cnt_value(4 downto 4)));
               
               memoryWait16(10)    <= gamepakWaitState(to_integer(wait_cnt_value(6 downto 5)));
               memoryWaitSeq16(10) <= gamepakWaitState1(to_integer(wait_cnt_value(7 downto 7)));
               memoryWait16(11)    <= gamepakWaitState(to_integer(wait_cnt_value(6 downto 5)));
               memoryWaitSeq16(11) <= gamepakWaitState1(to_integer(wait_cnt_value(7 downto 7)));
               
               memoryWait16(12)    <= gamepakWaitState(to_integer(wait_cnt_value(9 downto 8)));
               memoryWaitSeq16(12) <= gamepakWaitState2(to_integer(wait_cnt_value(10 downto 10)));
               memoryWait16(13)    <= gamepakWaitState(to_integer(wait_cnt_value(9 downto 8)));
               memoryWaitSeq16(13) <= gamepakWaitState2(to_integer(wait_cnt_value(10 downto 10)));
               
               busPrefetchEnable   <= wait_cnt_value(14);
            end if;
   
            if (wait_cnt_update_1 = '1') then
            
               for i in 8 to 14 loop
                  memoryWait32(i)    <= memoryWait16(i) + memoryWaitSeq16(i) + 1;
                  memoryWaitSeq32(i) <= memoryWaitSeq16(i) + memoryWaitSeq16(i) + 1;
               end loop;
               
            end if;
            
         end if;
         
         busPrefetchMax <= 8 * memoryWaitSeq16(to_integer(unsigned(PC(27 downto 24)))); 
      
         if (busPrefetchAdd = '1' and busPrefetchEnable = '1') then -- only add for internal and access from 0x2 to 0x7
            if (busPrefetchCnt + prefetch_addcycles >= busPrefetchMax) then
               busPrefetchCnt <= busPrefetchMax;
            else
               busPrefetchCnt <= busPrefetchCnt + prefetch_addcycles;
            end if;
         end if;
         
         if (busPrefetchSub = '1') then
            if (busPrefetchCnt - prefetch_subcycles < 0) then
               busPrefetchCnt <= 0;
            else
               busPrefetchCnt <= busPrefetchCnt - prefetch_subcycles;
            end if;
         end if;
         
         if (busPrefetchClear = '1' or unsigned(PC(27 downto 24)) < 16#8#) then -- clear when access to gamepak or jump
            busPrefetchCnt <= 0;
         end if;

      end if;
   end process;
   
   dataticksAccess16        <=    memoryWait16(to_integer(unsigned(busaddress(27 downto 24))));
   dataticksAccess32        <=    memoryWait32(to_integer(unsigned(busaddress(27 downto 24))));
   --dataticksAccessSeq16     <= memoryWaitSeq16(to_integer(unsigned(busaddress(27 downto 24)))); -- probably not required, as dataseq32 is only for block read/write and block cmd can only do 32bit accesses 
   dataticksAccessSeq32     <= memoryWaitSeq32(to_integer(unsigned(busaddress(27 downto 24))));
                            
   codeticksAccess16        <=    memoryWait16(to_integer(unsigned(PC(27 downto 24))));
   codeticksAccess32        <=    memoryWait32(to_integer(unsigned(PC(27 downto 24))));
   codeticksAccessSeq16     <= memoryWaitSeq16(to_integer(unsigned(PC(27 downto 24))));
   codeticksAccessSeq32     <= memoryWaitSeq32(to_integer(unsigned(PC(27 downto 24))));   
   
   codeticksAccessJump16    <=    memoryWait16(to_integer(unsigned(new_pc(27 downto 24))));
   codeticksAccessJump32    <=    memoryWait32(to_integer(unsigned(new_pc(27 downto 24))));
   codeticksAccessSeqJump16 <= memoryWaitSeq16(to_integer(unsigned(new_pc(27 downto 24))));
   codeticksAccessSeqJump32 <= memoryWaitSeq32(to_integer(unsigned(new_pc(27 downto 24))));  
   
   process (thumbmode, busPrefetchCnt, codeticksAccess16, codeticksAccessSeq16, codeticksAccess32, codeticksAccessSeq32)
   begin
   
      if (thumbmode = '1') then
         if (busPrefetchCnt > codeticksAccess16) then 
            codeticksAccess1632 <= 0; 
         else 
            codeticksAccess1632 <= codeticksAccess16 - busPrefetchCnt;
         end if;
         if (busPrefetchCnt > codeticksAccessSeq16) then 
            codeticksAccessSeq1632 <= 0; 
         else 
            codeticksAccessSeq1632 <= codeticksAccessSeq16 - busPrefetchCnt;
         end if;
      else
         if (busPrefetchCnt > codeticksAccess32) then 
            codeticksAccess1632 <= 0; 
         else 
            codeticksAccess1632 <= codeticksAccess32 - busPrefetchCnt;
         end if;
         if (busPrefetchCnt > codeticksAccessSeq32) then 
            codeticksAccessSeq1632 <= 0; 
         else 
            codeticksAccessSeq1632 <= codeticksAccessSeq32 - busPrefetchCnt;
         end if;
      end if;
        
      if (thumbmode = '1') then
         codeBaseAccess1632    <= codeticksAccess16;
         codeBaseAccessSeq1632 <= codeticksAccessSeq16;
      else
         codeBaseAccess1632    <= codeticksAccess32;
         codeBaseAccessSeq1632 <= codeticksAccessSeq32;
      end if;      
       
   end process;
   
   -- calc
   process (clk100) 
      variable new_pc_var  : unsigned(31 downto 0);
      variable new_value   : unsigned(31 downto 0);
      variable firstbitpos : integer range 0 to 15;
   begin
   
      if (rising_edge(clk100)) then
   
         execute_addcycles  <= 0;
         busPrefetchAdd     <= '0';
         busPrefetchSub     <= '0';
         busPrefetchClear   <= '0';
         prefetch_addcycles <= 0;
         prefetch_subcycles <= 0;
   
         if (reset = '1') then -- reset
            Flag_Zero       <= SAVESTATE_Flag_Zero;      
            Flag_Carry      <= SAVESTATE_Flag_Carry;     
            Flag_Negative   <= SAVESTATE_Flag_Negative;  
            Flag_V_Overflow <= SAVESTATE_Flag_V_Overflow;
            thumbmode       <= SAVESTATE_thumbmode;      
            cpu_mode        <= SAVESTATE_cpu_mode;       
            IRQ_disable     <= SAVESTATE_IRQ_disable;    
            FIQ_disable     <= SAVESTATE_FIQ_disable;    
            
            executebus      <= '0';
         elsif (gb_on = '1') then
      
            calc_done     <= '0';
            jump          <= '0';
            branchnext    <= '0';
            blockr15jump  <= '0';
            
            bus_execute_ena <= '0';
            
            bus_lowbits     <= "00";
            
            execute_writeback_calc     <= '0';
            execute_writeback_r17      <= '0';
            execute_writeback_userreg  <= '0';
            execute_switchregs         <= '0';
            execute_saveregs           <= '0';
            execute_saveState          <= '0';
            execute_SWI                <= '0';
            execute_IRP                <= '0';
            
            shifter_start              <= '0';
            
            if ((execute_writeback_calc = '1' and writeback_reg = x"F" and blockr15jump = '0')) then
               branchnext       <= '1';
               if (thumbmode = '1') then
                  new_pc     <= calc_result(new_pc'left downto 1) & '0';
               else
                  new_pc     <= calc_result(new_pc'left downto 2) & "00";
               end if;
            end if;
            
            if (branchnext = '1') then
               busPrefetchClear <= '1';
               jump             <= '1';
               calc_done        <= '1';
               if (thumbmode = '1') then
                  execute_addcycles <= 3 + (codeTicksAccessSeqJump16 * 2) + codeTicksAccessJump16;
               else
                  execute_addcycles <= 3 + (codeTicksAccessSeqJump32 * 2) + codeTicksAccessJump32;
               end if;
            end if;
            
            if (irq_calc = '1') then
               calc_result            <= execute_PCprev + 4; -- working code suggests always +4 even for thumbmode? seems to be correct!
               execute_writeback_calc <= '1';
               writeback_reg          <= x"E";
               
               execute_saveState  <= '1';
               execute_switchregs <= '1';
               execute_saveregs   <= '1';
               execute_IRP        <= '1';
               cpu_mode_old       <= cpu_mode;
               cpu_mode           <= CPUMODE_IRQ;
               thumbmode          <= '0';
               IRQ_disable        <= '1';
               new_pc             <= to_unsigned(16#18#, new_pc'length);
               jump               <= '1';
               calc_done          <= '1';
            end if;
         
            case execute_functions_detail is
            
               when alu_and | alu_xor | alu_add | alu_sub | alu_add_withcarry | alu_sub_withcarry | alu_or | alu_mov | alu_and_not | alu_mov_not =>
                  case (alu_stage) is
                     when ALUSTART =>
                        if (execute_start = '1') then
                           if (execute_alu_use_shift = '1') then
                              alu_stage     <= ALUSHIFT;
                              shifter_start <= '1';
                           else
                              if (execute_switch_op = '1') then
                                 alu_stage <= ALUSWITCHOP;
                              else
                                 alu_stage <= ALUCALC;
                              end if;
                           end if;
                        end if;
                        alu_op1 <= regs(to_integer(unsigned(execute_Rn_op1)));
                        if (execute_clearbit1 = '1') then
                           alu_op1(1) <= '0';
                        end if;
                        if (execute_alu_use_immi = '1') then
                           alu_op2 <= execute_immidiate;
                        else
                           alu_op2  <= regs(to_integer(unsigned(execute_Rm_op2)));
                           shiftreg <= regs(to_integer(unsigned(execute_Rm_op2)));
                        end if;
                        shiftbyreg       <= regs(to_integer(unsigned(execute_shiftsettings(7 downto 4))))(7 downto 0);
                        alu_shiftercarry <= execute_shiftcarry;
                        if (execute_useoldcarry = '1') then
                           alu_shiftercarry <= Flag_Carry;
                        end if;
                        
                     when ALUSHIFT =>
                        if (execute_shiftsettings = x"00") then
                           if (execute_switch_op = '1') then
                              alu_stage <= ALUSWITCHOP;
                           else
                              alu_stage <= ALUCALC;
                           end if;
                        else
                           alu_stage    <= ALUSHIFTWAIT;
                           shiftwait    <= 2;
                        end if;
                        if (execute_shiftsettings(0) = '1') then
                           execute_addcycles  <= 1;
                           prefetch_addcycles <= 1;
                           busPrefetchAdd     <= '1';
                           if (execute_Rn_op1 = x"F") then
                              alu_op1 <= regs_plus_12;
                           end if;
                        end if;
                        
                     when ALUSHIFTWAIT =>
                        if (shiftwait > 0) then
                           shiftwait <= shiftwait - 1;
                        else
                           alu_op2          <= shiftresult;
                           alu_shiftercarry <= shiftercarry;
                           if (execute_switch_op = '1') then
                              alu_stage <= ALUSWITCHOP;
                           else
                              alu_stage <= ALUCALC;
                           end if;
                        end if;
                        
                     when ALUSWITCHOP =>
                        alu_op1 <= alu_op2;
                        alu_op2 <= alu_op1;
                        alu_stage <= ALUCALC;
                        
                     when ALUCALC  => 
                        case (execute_functions_detail) is
                           when alu_and =>     alu_result <= alu_op1 and alu_op2;          
                           when alu_xor =>     alu_result <= alu_op1 xor alu_op2;       
                           when alu_or  =>     alu_result <= alu_op1  or alu_op2;         
                           when alu_and_not => alu_result <= alu_op1 and (not alu_op2);                                     
                           when alu_mov =>     alu_result <= alu_op2;                      
                           when alu_mov_not => alu_result <= not alu_op2;                  
                              
                           when alu_add => 
                              alu_result_add <= ('0' & alu_op1) + ('0' & alu_op2);
                           
                           when alu_sub => 
                              alu_result <= alu_op1 - alu_op2;
                           
                           when alu_add_withcarry =>
                              if (Flag_Carry = '1') then
                                 alu_result_add <= ('0' & alu_op1) + ('0' & alu_op2) + to_unsigned(1, 33);
                              else
                                 alu_result_add <= ('0' & alu_op1) + ('0' & alu_op2);
                              end if;
                           
                           when alu_sub_withcarry =>
                              if (Flag_Carry = '1') then
                                 alu_result <= alu_op1 - alu_op2;
                              else
                                 alu_result <= alu_op1 - alu_op2 - 1;
                              end if;
 
                           when others => report "should never happen" severity failure;
                        end case;
                        alu_stage <= ALUSETFLAGS;
                        
                     when ALUSETFLAGS =>
                        if (execute_leaveirp = '1') then
                           alu_stage              <= ALULEAVEIRP;
                        else
                           alu_stage              <= ALUSTART;
                           calc_done              <= '1';
                           execute_writeback_calc <= execute_writeback;
                           writeback_reg          <= execute_rdest;
                           if (execute_rdest /= x"F") then
                              execute_addcycles      <= 1 + codeticksAccessSeq1632;
                              busPrefetchSub         <= '1';
                              prefetch_subcycles     <= codeBaseAccessSeq1632;
                           end if;
                        end if;
                        
                        if (execute_updateflags = '1') then
                        
                           if (alu_result = 0) then Flag_Zero <= '1'; else Flag_Zero <= '0'; end if;
                           Flag_Negative <= alu_result(31);
                        
                           case (execute_functions_detail) is
                              when alu_and =>     Flag_Carry <= alu_shiftercarry; 
                              when alu_xor =>     Flag_Carry <= alu_shiftercarry; 
                              when alu_or  =>     Flag_Carry <= alu_shiftercarry; 
                              when alu_and_not => Flag_Carry <= alu_shiftercarry;                                  
                              when alu_mov =>     Flag_Carry <= alu_shiftercarry; 
                              when alu_mov_not => Flag_Carry <= alu_shiftercarry; 
                              
                              when alu_add | alu_add_withcarry =>  
                                 if (alu_result_add(31 downto 0) = 0) then Flag_Zero <= '1'; else Flag_Zero <= '0'; end if;
                                 Flag_Negative <= alu_result_add(31);
                                 Flag_Carry <= alu_result_add(32);
                                 if ((alu_op1(31) xor alu_result_add(31)) = '1' and (alu_op2(31) xor alu_result_add(31)) = '1') then
                                    Flag_V_Overflow <= '1';
                                 else
                                    Flag_V_Overflow <= '0';
                                 end if;
                              
                              when alu_sub => 
                                 if (alu_op1(31) /= alu_op2(31) and alu_op1(31) /= alu_result(31)) then
                                    Flag_V_Overflow <= '1';
                                 else
                                    Flag_V_Overflow <= '0';
                                 end if;
                                 if (alu_op1 >= alu_op2) then -- subs -> carry is 0 if borror, 1 otherwise
                                    Flag_Carry <= '1'; 
                                 else
                                    Flag_Carry <= '0'; 
                                 end if;
                              
                              when alu_sub_withcarry =>
                                 if (alu_op1(31) /= alu_op2(31) and alu_op1(31) /= alu_result(31)) then
                                    Flag_V_Overflow <= '1';
                                 else
                                    Flag_V_Overflow <= '0';
                                 end if;
                                 if (Flag_Carry = '1') then
                                    if (alu_op1 >= alu_op2) then
                                       Flag_Carry <= '1'; 
                                    else
                                       Flag_Carry <= '0'; 
                                    end if;
                                 else
                                    if (alu_op1 = 0) then
                                       Flag_Carry <= '0'; 
                                    elsif ((alu_op1 - 1) >= alu_op2) then
                                       Flag_Carry <= '1'; 
                                    else
                                       Flag_Carry <= '0'; 
                                    end if;
                                 end if;
                           
                              when others => report "should never happen" severity failure;
                           end case;
                        end if;
                        
                        if (execute_functions_detail = alu_add or execute_functions_detail = alu_add_withcarry) then
                           calc_result <= alu_result_add(31 downto 0);
                        else
                           calc_result <= alu_result;
                        end if;
                        
                     when ALULEAVEIRP =>
                        alu_stage              <= ALUSTART;
                        calc_done              <= '1';
                        execute_writeback_calc <= execute_writeback;
                        writeback_reg          <= execute_rdest;
                        execute_saveregs       <= '1';
                        execute_saveState      <= '0';
                        execute_switchregs     <= '1';
                        if (
                              (cpu_mode = CPUMODE_USER   and (std_logic_vector(regs(17)(3 downto 0)) = CPUMODE_USER or std_logic_vector(regs(17)(3 downto 0)) = CPUMODE_SYSTEM)) or
                              (cpu_mode = CPUMODE_SYSTEM and (std_logic_vector(regs(17)(3 downto 0)) = CPUMODE_USER or std_logic_vector(regs(17)(3 downto 0)) = CPUMODE_SYSTEM))
                          ) then
                           execute_switchregs  <= '0';
                        end if;
                        cpu_mode_old           <= cpu_mode;
                        if (execute_leaveirp_user = '0') then
                           cpu_mode               <= std_logic_vector(regs(17)(3 downto 0));
                           thumbmode              <= regs(17)(5);
                           FIQ_disable            <= regs(17)(6);
                           IRQ_disable            <= regs(17)(7);
                           Flag_Negative          <= regs(17)(31);
                           Flag_Zero              <= regs(17)(30);
                           Flag_Carry             <= regs(17)(29);
                           Flag_V_Overflow        <= regs(17)(28);
                        end if;
               
                  end case;
                  
               when mulboth =>
                  case (mul_stage) is
                     when MULSTART =>
                        if (execute_start = '1') then
                           mul_op1       <= regs(to_integer(unsigned(execute_Rn_op1))); 
                           mul_op2       <= regs(to_integer(unsigned(execute_RM_op2))); -- to be used for timing
                           mul_opaddlow  <= regs(to_integer(unsigned(execute_muladd)));
                           mul_opaddhigh <= regs(to_integer(unsigned(execute_rdest)));
                           mul_stage <= MULCALCMUL;
                           mul_wait  <= 3;
                           if (execute_mul_long = '1') then
                              execute_addcycles  <= 1;
                              prefetch_addcycles <= 1;
                              busPrefetchAdd     <= '1';
                           end if;
                        end if;
                     
                     when MULCALCMUL =>
                        if (execute_mul_long = '0' or execute_mul_signed = '0') then
                           mul_result <= mul_op1 * mul_op2;
                        else
                           mul_result <= unsigned(signed(mul_op1) * signed(mul_op2));
                        end if;
                        if (mul_wait > 0) then
                           mul_wait <= mul_wait - 1;
                        else
                           if (execute_mul_useadd = '1') then
                              mul_stage <= MULADDLOW;
                           elsif (execute_updateflags = '1') then
                              mul_stage <= MULSETFLAGS;
                           else
                              mul_stage <= MULWRITEBACK_LOW;
                           end if;
                           
                        end if;
                        -- timing
                        if (mul_wait = 3) then
                           busPrefetchAdd    <= '1';
                           execute_addcycles <= 4; 
                           prefetch_addcycles <= 4;
                              if (mul_op2(31 downto 8)  = x"000000" or mul_op2(31 downto 8)  = x"FFFFFF") then execute_addcycles <= 1; prefetch_addcycles <= 1;
                           elsif (mul_op2(31 downto 16) = x"0000"   or mul_op2(31 downto 16) = x"FFFF")   then execute_addcycles <= 2; prefetch_addcycles <= 2;
                           elsif (mul_op2(31 downto 24) = x"00"     or mul_op2(31 downto 24) = x"FF")     then execute_addcycles <= 3; prefetch_addcycles <= 3; end if;  
                        end if;
                        if (mul_wait = 2 and execute_mul_useadd = '1') then
                           execute_addcycles  <= 1;
                           busPrefetchAdd     <= '1';
                           prefetch_addcycles <= 1;
                        end if;
                     
                     when MULADDLOW =>
                        if (execute_mul_useadd = '1') then
                           mul_result         <= mul_result + mul_opaddlow;
                        end if;
                        if (execute_mul_long = '1') then
                           mul_stage <= MULADDHIGH;
                        elsif (execute_updateflags = '1') then
                           mul_stage <= MULSETFLAGS;
                        else
                           mul_stage <= MULWRITEBACK_LOW;
                        end if;
                     
                     when MULADDHIGH =>
                        mul_result <= mul_result + (mul_opaddhigh & x"00000000");
                        if (execute_updateflags = '1') then
                           mul_stage <= MULSETFLAGS;
                        else
                           mul_stage <= MULWRITEBACK_LOW;
                        end if;
                     
                     when MULSETFLAGS =>
                        mul_stage <= MULWRITEBACK_LOW;
                        if (execute_mul_long = '1') then
                           if (mul_result = 0) then Flag_Zero <= '1'; else Flag_Zero <= '0'; end if;
                           Flag_Negative <= mul_result(63);
                        else
                           if (mul_result(31 downto 0) = 0) then Flag_Zero <= '1'; else Flag_Zero <= '0'; end if;
                           Flag_Negative <= mul_result(31);
                        end if;
                     
                     when MULWRITEBACK_LOW =>
                        execute_writeback_calc <= '1';
                        calc_result            <= mul_result(31 downto 0);
                        if (execute_mul_long = '1') then
                           mul_stage     <= MULWRITEBACK_HIGH;
                           writeback_reg <= execute_muladd;
                        else
                           writeback_reg <= execute_rdest;
                           mul_stage <= MULSTART;
                           calc_done <= '1';
                           -- timing
                           busPrefetchSub <= '1';
                           if (busPrefetchEnable = '1') then
                              execute_addcycles  <= 1 + codeticksAccessSeq1632;
                              prefetch_subcycles <= codeBaseAccessSeq1632;
                           else
                              execute_addcycles  <= 1 + codeticksAccess1632;
                              prefetch_subcycles <= codeBaseAccess1632;
                           end if;
                        end if;
                     
                     when MULWRITEBACK_HIGH =>
                        mul_stage <= MULSTART;
                        calc_done <= '1';
                        writeback_reg          <= execute_rdest;
                        execute_writeback_calc <= '1';
                        calc_result            <= mul_result(63 downto 32);
                        -- timing
                        busPrefetchSub         <= '1';
                        if (busPrefetchEnable = '1') then
                           execute_addcycles  <= 1 + codeticksAccessSeq1632;
                           prefetch_subcycles <= codeBaseAccessSeq1632;
                        else
                           execute_addcycles  <= 1 + codeticksAccess1632;
                           prefetch_subcycles <= codeBaseAccess1632;
                        end if;
                              
                  end case;
                  
               when data_processing_MRS =>
                  if (execute_start = '1') then
                     calc_done <= '1';
                     writeback_reg          <= execute_rdest;
                     execute_writeback_calc <= '1';
                     if (execute_psr_with_spsr = '1') then
                        calc_result <= regs(17);
                     else
                        calc_result <= regs(16);
                     end if;
                     execute_addcycles      <= 1 + codeticksAccessSeq1632;
                     busPrefetchSub         <= '1';
                     prefetch_subcycles     <= codeBaseAccessSeq1632;
                  end if;               
                  
               when data_processing_MSR =>
                  case (MSR_Stage) is
                     when MSR_START =>
                        if (execute_start = '1') then
                           if (execute_alu_use_immi = '1') then
                              msr_value <= execute_immidiate(31 downto 24) & x"00000" & execute_immidiate(3 downto 0); -- immidiate is for flags only
                           else
                              msr_value <= regs(to_integer(unsigned(execute_Rm_op2)));
                           end if;
                           msr_writebackvalue <= regs(17);
                           if (execute_psr_with_spsr = '1') then
                              MSR_Stage <= MSR_SPSR;
                           else
                              MSR_Stage <= MSR_CPSR;
                           end if;
                        end if;
                        
                     when MSR_SPSR =>
                        MSR_Stage <= MSR_START;
                        calc_done <= '1';
                        execute_writeback_r17 <= '1';
                        if (cpu_mode /= CPUMODE_USER) then
                           if (execute_Rn_op1(0) = '1') then msr_writebackvalue( 7 downto  0) <= msr_value( 7 downto  0); end if;
                           if (execute_Rn_op1(1) = '1') then msr_writebackvalue(15 downto  8) <= msr_value(15 downto  8); end if;
                           if (execute_Rn_op1(2) = '1') then msr_writebackvalue(23 downto 16) <= msr_value(23 downto 16); end if;
                           if (execute_Rn_op1(3) = '1') then msr_writebackvalue(31 downto 24) <= msr_value(31 downto 24); end if;
                        end if;
                        execute_addcycles      <= 1 + codeticksAccessSeq1632;
                        busPrefetchSub         <= '1';
                        prefetch_subcycles     <= codeBaseAccessSeq1632;
                        
                     when MSR_CPSR =>
                        calc_done      <= '1';
                        MSR_Stage      <= MSR_START;
                        new_value := regs(16);
                        if (execute_alu_use_immi = '1') then
                           new_value(31 downto 24) := msr_value(31 downto 24);
                        end if;
                        if (cpu_mode /= CPUMODE_USER) then
                           if (execute_Rn_op1(0) = '1') then new_value( 7 downto  0) := msr_value( 7 downto  0); end if;
                           if (execute_Rn_op1(1) = '1') then new_value(15 downto  8) := msr_value(15 downto  8); end if;
                           if (execute_Rn_op1(2) = '1') then new_value(23 downto 16) := msr_value(23 downto 16); end if;
                        end if;
                        if (execute_Rn_op1(3) = '1') then new_value(31 downto 24) := msr_value(31 downto 24); end if;
                        if (cpu_mode /= std_logic_vector(new_value(3 downto 0))) then
                           execute_switchregs <= '1';
                        end if;
                        if (
                              (cpu_mode = CPUMODE_USER   and (std_logic_vector(new_value(3 downto 0)) = CPUMODE_USER or std_logic_vector(new_value(3 downto 0)) = CPUMODE_SYSTEM)) or
                              (cpu_mode = CPUMODE_SYSTEM and (std_logic_vector(new_value(3 downto 0)) = CPUMODE_USER or std_logic_vector(new_value(3 downto 0)) = CPUMODE_SYSTEM))
                          ) then
                           execute_switchregs  <= '0';
                        end if;
                        execute_saveregs   <= '1';
                        cpu_mode_old       <= cpu_mode;
                        cpu_mode           <= std_logic_vector(new_value(3 downto 0));
                        thumbmode          <= new_value(5);
                        FIQ_disable        <= new_value(6);
                        IRQ_disable        <= new_value(7);
                        Flag_Negative      <= new_value(31);
                        Flag_Zero          <= new_value(30);
                        Flag_Carry         <= new_value(29);
                        Flag_V_Overflow    <= new_value(28);
                        if (thumbmode /= new_value(5)) then
                           new_pc             <= execute_PC;
                           jump               <= '1';
                        else
                           execute_addcycles  <= 1 + codeticksAccessSeq1632;
                           busPrefetchSub     <= '1';
                           prefetch_subcycles <= codeBaseAccessSeq1632;
                        end if;
                        
                        
                  end case;
                  
               when branch_all =>
                  if (execute_start = '1') then
                     if (execute_branch_link = '1') then
                        calc_result            <= execute_PC;
                        execute_writeback_calc <= '1';
                        writeback_reg          <= execute_rdest;
                     end if;
                     branchnext   <= '1';
                     if (execute_branch_usereg = '1') then
                        new_pc_var := regs(to_integer(unsigned(execute_Rm_op2)));
                     else
                        new_pc_var := to_unsigned(to_integer(regs(15)) + to_integer(execute_branch_immi), new_pc_var'length); 
                     end if;
                     if (execute_set_thumbmode = '1') then
                        thumbmode <= new_pc_var(0);
                        if (new_pc_var(0) = '1') then
                           new_pc <= new_pc_var(31 downto 1) & '0';
                        else
                           new_pc <= new_pc_var(31 downto 2) & "00";
                        end if;
                     else
                        if (thumbmode = '1') then
                           new_pc <= new_pc_var(31 downto 1) & '0';
                        else
                           new_pc <= new_pc_var(31 downto 2) & "00";
                        end if;
                     end if;
                  end if;
                  
               when data_read | data_write =>
                  case (data_rw_stage) is
                     when FETCHADDR =>
                        if (execute_start = '1') then
                           swap_write       <= '0';
                           if (execute_datatransfer_swap = '1') then
                              gb_bus_dout <= std_logic_vector(regs(to_integer(unsigned(execute_RM_op2))));
                           elsif (execute_rdest = x"F") then  -- pc is + 12 for data writes
                              gb_bus_dout <= std_logic_vector(regs_plus_12);  
                           else
                              gb_bus_dout <= std_logic_vector(regs(to_integer(unsigned(execute_rdest))));
                           end if;
                           busaddress <= regs(to_integer(unsigned(execute_Rn_op1)))(busaddress'left downto 0);
                           if (execute_Rn_op1 = x"F") then -- for pc relative load -> word aligned
                              busaddress(1) <= '0';
                           end if;
                           if (execute_datatransfer_regoffset = '1') then
                              busaddmod  <= regs(to_integer(unsigned(execute_Rm_op2)))(busaddress'left downto 0);
                              shiftreg   <= regs(to_integer(unsigned(execute_Rm_op2)));
                           else
                              busaddmod  <= x"00000" & execute_datatransfer_addvalue;
                           end if;
                           shiftbyreg <= regs(to_integer(unsigned(execute_shiftsettings(7 downto 4))))(7 downto 0);
                           if (execute_datatransfer_shiftval = '1') then
                              data_rw_stage <= BUSSHIFT;
                              shifter_start <= '1';
                           else
                              data_rw_stage <= CALCADDR;
                           end if;
                        end if;
                        
                     when BUSSHIFT =>  
                        if (execute_shiftsettings = x"00") then
                           data_rw_stage <= CALCADDR;
                        else
                           data_rw_stage <= BUSSHIFTWAIT;
                           shiftwait     <= 2;
                        end if;
                        if (execute_shiftsettings(0) = '1') then
                           execute_addcycles  <= 1;
                           busPrefetchAdd     <= '1';
                           prefetch_addcycles <= 1;
                        end if;
                        
                     when BUSSHIFTWAIT =>
                        if (shiftwait > 0) then
                           shiftwait <= shiftwait - 1;
                        else
                           busaddmod     <= shiftresult(busaddmod'left downto 0);
                           data_rw_stage <= CALCADDR;
                        end if;
                        
                     when CALCADDR =>
                        data_rw_stage <= BUSREQUEST;
                        if (execute_datatransfer_preadd = '1') then
                           if (execute_datatransfer_addup = '1') then
                              busaddress <= busaddress + busaddmod;
                           else
                              busaddress <= busaddress - busaddmod;
                           end if;
                        end if;
                        
                     when BUSREQUEST =>
                        if (fetch_available = '1' and decode_request = '0') then
                           executebus      <= '1'; 
                           data_rw_stage   <= WAITBUS;
                           bus_execute_Adr <= std_logic_vector(busaddress);
                           if (execute_clearbit1 = '1') then
                              bus_execute_Adr(1) <= '0';
                           end if;
                           if (execute_functions_detail = data_read and swap_write = '0') then
                              bus_execute_rnw <= '1';
                           else
                              bus_execute_rnw <= '0';
                           end if;
                           bus_execute_ena <= '1';
                           bus_execute_acc <= execute_datatransfer_type; 
                           
                           --timing
                           if (execute_datatransfer_swap = '1' and swap_write = '0') then
                              busPrefetchAdd     <= '1';
                              busPrefetchClear   <= busaddress(27);
                              execute_addcycles  <= 3 + dataTicksAccess32 + dataTicksAccess32;
                              prefetch_addcycles <= 3 + dataTicksAccess32 + dataTicksAccess32 + (codeticksAccess16 - codeticksAccessSeq16 - 1);
                           elsif (execute_datatransfer_swap = '0') then
                              busPrefetchAdd    <= '1';
                              busPrefetchClear  <= busaddress(27);
                              if (execute_functions_detail = data_read) then
                                 case (execute_datatransfer_type) is
                                    when ACCESS_8BIT | ACCESS_16BIT => 
                                       execute_addcycles  <= 3 + dataTicksAccess16;
                                       prefetch_addcycles <= 3 + dataTicksAccess16 + (codeticksAccess16 - codeticksAccessSeq16 - 1);
                                    when ACCESS_32BIT               => 
                                       execute_addcycles  <= 3 + dataTicksAccess32;
                                       prefetch_addcycles <= 3 + dataTicksAccess32 + (codeticksAccess16 - codeticksAccessSeq16 - 1);
                                    when others => null;
                                 end case;
                              else
                                 case (execute_datatransfer_type) is
                                    when ACCESS_8BIT | ACCESS_16BIT => 
                                       execute_addcycles  <= 2 + dataTicksAccess16;
                                       prefetch_addcycles <= 2 + dataTicksAccess16 + (codeticksAccess16 - codeticksAccessSeq16 - 1);
                                    when ACCESS_32BIT => 
                                       execute_addcycles  <= 2 + dataTicksAccess32;
                                       prefetch_addcycles <= 2 + dataTicksAccess32 + (codeticksAccess16 - codeticksAccessSeq16 - 1);
                                    when others => null;
                                 end case;
                              end if;
                           end if;
                           
                        end if;
                        
                     when WAITBUS =>
                        if (gb_bus_done = '1') then
                           executebus  <= '0';
                           if (execute_functions_detail = data_read) then
                              case (execute_datareceivetype) is
                                 when RECEIVETYPE_BYTE       => calc_result <= x"000000" & unsigned(gb_bus_din(7 downto 0));
                                 when RECEIVETYPE_WORD       => calc_result <= unsigned(gb_bus_din); -- !!!
                                 when RECEIVETYPE_DWORD      => calc_result <= unsigned(gb_bus_din);
                                 when RECEIVETYPE_SIGNEDBYTE => calc_result <= unsigned(resize(signed(gb_bus_din(7 downto 0)), 32));
                                 when RECEIVETYPE_SIGNEDWORD => 
                                    if (busaddress(0) = '0') then
                                       calc_result <= unsigned(resize(signed(gb_bus_din(15 downto 0)), 32));
                                    else
                                       calc_result <= unsigned(resize(signed(gb_bus_din(7 downto 0)), 32));
                                    end if;                                    
                                      
                              end case;
                              execute_writeback_calc <= '1';
                              writeback_reg          <= execute_rdest;
                           end if;
                           
                           if (execute_datatransfer_preadd = '0') then
                              if (execute_datatransfer_addup = '1') then
                                 busaddress <= busaddress + busaddmod;
                              else
                                 busaddress <= busaddress - busaddmod;
                              end if;
                           end if;
                           
                           if (execute_datatransfer_swap = '1' and swap_write = '0') then
                              data_rw_stage      <= BUSREQUEST;
                              swap_write         <= '1';
                              execute_addcycles  <= codeticksAccess1632;
                              busPrefetchSub     <= '1';
                              prefetch_subcycles <= codeBaseAccess1632;
                           else
                              if (execute_datatransfer_writeback = '1') then
                                 data_rw_stage <= WRITEBACKADDR;
                              else
                                 data_rw_stage <= FETCHADDR;
                                 calc_done  <= '1';
                              end if;
                           end if;
                           -- timing
                           if (execute_datatransfer_swap = '0') then
                              if (execute_rdest /= x"F" or execute_functions_detail = data_write) then
                                 execute_addcycles  <= codeticksAccess1632; 
                                 busPrefetchSub     <= '1';
                                 prefetch_subcycles <= codeBaseAccess1632;
                              end if;
                           end if;
                        end if;
                        
                     when WRITEBACKADDR =>
                        writeback_reg          <= execute_Rn_op1;
                        calc_result            <= busaddress;
                        execute_writeback_calc <= '1';
                        data_rw_stage          <= FETCHADDR;
                        calc_done              <= '1';

                  end case; 
                  
               when block_read | block_write =>
                  case (block_rw_stage) is
                     when BLOCKFETCHADDR =>
                        if (execute_start = '1') then
                           first_mem_access <= '1';
                           block_regindex   <= 0;
                           busaddress       <= to_unsigned(to_integer(regs(to_integer(unsigned(execute_Rn_op1)))(busaddress'left downto 0)) + execute_block_addrmod, busaddress'length);
                           endaddress       <= to_unsigned(to_integer(regs(to_integer(unsigned(execute_Rn_op1)))(busaddress'left downto 0)) + execute_block_endmod, busaddress'length);
                           endaddressRlist  <= to_unsigned(to_integer(regs(to_integer(unsigned(execute_Rn_op1)))(busaddress'left downto 0)) + execute_block_addrmod_baseRlist, busaddress'length);          
                           block_reglist    <= execute_block_reglist;
                           block_rw_stage   <= BLOCKCHECKNEXT;
                           block_switch_pc  <= execute_PC;
                        end if;
                        
                     when BLOCKCHECKNEXT => 
                        firstbitpos := 0;
                        for i in 15 downto 1 loop
                           if (block_reglist(i) = '1') then
                              firstbitpos := i;
                           end if;
                        end loop;

                        if (block_reglist(0) = '1') then
                           block_reglist  <= '0' & block_reglist(15 downto 1);
                           if (execute_functions_detail = block_read) then
                              block_rw_stage  <= BLOCKREAD;
                           else
                              block_rw_stage  <= BLOCKWRITE;
                           end if;
                        else
                           block_reglist  <= std_logic_vector(unsigned(block_reglist) srl firstbitpos);
                           block_regindex <= block_regindex + firstbitpos;
                        end if;
                        
                        if (block_reglist = x"0000") then
                           if (execute_datatransfer_writeback = '1') then
                              block_rw_stage  <= BLOCKWRITEBACKADDR;
                              if (execute_datatransfer_addup = '1') then
                                 if (execute_datatransfer_preadd = '1') then
                                    busaddress <= busaddress - 4;
                                 end if;
                              else
                                 busaddress <= endaddress;
                              end if;
                              if (execute_block_emptylist = '1') then
                                 busaddress <= endaddress;
                              end if;
                           elsif (execute_block_switchmode = '1') then
                              block_rw_stage         <= BLOCKSWITCHMODE;
                           else
                              block_rw_stage         <= BLOCKFETCHADDR;
                              calc_done              <= '1';
                              if (execute_block_reglist(15) = '0' or execute_functions_detail = block_write) then
                                 execute_addcycles  <= 1 + codeticksAccess1632;
                                 busPrefetchSub     <= '1';
                                 prefetch_subcycles <= codeBaseAccess1632;
                              end if;
                           end if;
                        end if;
                        
                        if (execute_block_usermoderegs = '1' and cpu_mode /= CPUMODE_USER and cpu_mode /= CPUMODE_SYSTEM) then
                           case (block_regindex) is
                              when 8  => block_writevalue <= regs_0_8;
                              when 9  => block_writevalue <= regs_0_9;
                              when 10 => block_writevalue <= regs_0_10;
                              when 11 => block_writevalue <= regs_0_11;
                              when 12 => block_writevalue <= regs_0_12;
                              when 13 => block_writevalue <= regs_0_13;
                              when 14 => block_writevalue <= regs_0_14;
                              when others => block_writevalue <= (others => '0'); -- never happens in armwrestler or suite...
                           end case;
                        elsif (block_regindex = 15) then  -- pc is +6/12 for block writes
                           block_writevalue     <= block_pc_next;  
                        elsif (first_mem_access = '0' and to_integer(unsigned(execute_Rn_op1)) = block_regindex) then
                           block_writevalue     <= endaddressRlist;
                        else
                           block_writevalue     <= regs(block_regindex);
                        end if;
                        
                     when BLOCKWRITE =>
                        if (fetch_available = '1' and decode_request = '0') then
                           executebus      <= '1';
                           gb_bus_dout     <= std_logic_vector(block_writevalue);
                           bus_execute_Adr <= std_logic_vector(busaddress(busaddress'left downto 2)) & "00";
                           bus_lowbits     <= std_logic_vector(busaddress(1 downto 0));
                           bus_execute_rnw <= '0';
                           bus_execute_ena <= '1';
                           bus_execute_acc <= ACCESS_32BIT;
                           block_rw_stage  <= BLOCKWAITWRITE;
                           -- timing
                           first_mem_access <= '0';
                           busPrefetchAdd   <= '1';
                           busPrefetchClear <= busaddress(27);
                           if (first_mem_access = '1') then
                              execute_addcycles  <= 1 + dataTicksAccess32;
                              prefetch_addcycles <= 2 + dataTicksAccess32 + (codeticksAccess16 - codeticksAccessSeq16 - 1);
                           else
                              execute_addcycles  <= 1 + dataTicksAccessSeq32;
                              prefetch_addcycles <= 1 + dataTicksAccessSeq32 + (codeticksAccess16 - codeticksAccessSeq16 - 1);
                           end if;
                        end if;
                        
                     when BLOCKWAITWRITE =>
                        if (gb_bus_done = '1') then
                           executebus      <= '0';
                           block_rw_stage  <= BLOCKCHECKNEXT;
                           busaddress      <= busaddress + 4;
                           if (block_regindex < 15) then
                              block_regindex <= block_regindex + 1;
                           end if;
                        end if;
                        
                     when BLOCKREAD =>
                        if (fetch_available = '1' and decode_request = '0') then
                           executebus      <= '1';
                           bus_execute_Adr <= std_logic_vector(busaddress(busaddress'left downto 2)) & "00";
                           bus_lowbits     <= std_logic_vector(busaddress(1 downto 0));
                           bus_execute_rnw <= '1';
                           bus_execute_ena <= '1';
                           bus_execute_acc <= ACCESS_32BIT;
                           block_rw_stage  <= BLOCKWAITREAD;
                           -- timing
                           first_mem_access <= '0';
                           busPrefetchAdd   <= '1';
                           busPrefetchClear <= busaddress(27);
                           if (first_mem_access = '1') then
                              execute_addcycles  <= 2 + dataTicksAccess32;
                              prefetch_addcycles <= 3 + dataTicksAccess32 + (codeticksAccess16 - codeticksAccessSeq16 - 1);
                           else
                              execute_addcycles  <= 1 + dataTicksAccessSeq32;
                              prefetch_addcycles <= 1 + dataTicksAccessSeq32 + (codeticksAccess16 - codeticksAccessSeq16 - 1);
                           end if;
                        end if;
                      
                     when BLOCKWAITREAD =>
                        if (gb_bus_done = '1') then
                           block_rw_stage  <= BLOCKCHECKNEXT;
                           busaddress      <= busaddress + 4;
                           if (block_regindex < 15) then
                              block_regindex <= block_regindex + 1;
                           end if;
                           calc_result <= unsigned(gb_bus_din);
                           executebus  <= '0';
                           if (execute_block_usermoderegs = '1' and cpu_mode /= CPUMODE_USER and cpu_mode /= CPUMODE_SYSTEM) then
                              execute_writeback_userreg <= '1';
                           else
                              execute_writeback_calc    <= '1';
                           end if;
                           writeback_reg             <= std_logic_vector(to_unsigned(block_regindex, 4));
                           if (block_regindex = 15) then
                              block_switch_pc <= unsigned(gb_bus_din);
                              blockr15jump    <= execute_block_switchmode;
                           end if;
                        end if;

                     when BLOCKWRITEBACKADDR =>
                        writeback_reg          <= execute_Rn_op1;
                        calc_result            <= busaddress;
                        execute_writeback_calc <= '1';
                        if (execute_block_switchmode = '1') then
                           block_rw_stage         <= BLOCKSWITCHMODE;
                        else
                           block_rw_stage         <= BLOCKFETCHADDR;
                           calc_done              <= '1';
                           if (execute_block_reglist(15) = '0' or execute_functions_detail = block_write) then
                              execute_addcycles <= 1 + codeticksAccess1632;
                              busPrefetchSub     <= '1';
                              prefetch_subcycles <= codeBaseAccess1632;
                           end if;
                        end if;
                        
                     when BLOCKSWITCHMODE =>
                        block_rw_stage     <= BLOCKFETCHADDR;
                        calc_done          <= '1';
                        execute_saveState  <= '1';
                        execute_switchregs <= '1';
                        if (
                              (cpu_mode = CPUMODE_USER   and (std_logic_vector(regs(17)(3 downto 0)) = CPUMODE_USER or std_logic_vector(regs(17)(3 downto 0)) = CPUMODE_SYSTEM)) or
                              (cpu_mode = CPUMODE_SYSTEM and (std_logic_vector(regs(17)(3 downto 0)) = CPUMODE_USER or std_logic_vector(regs(17)(3 downto 0)) = CPUMODE_SYSTEM))
                          ) then
                           execute_switchregs  <= '0';
                        end if;
                        execute_saveregs   <= '1';
                        cpu_mode_old       <= cpu_mode;
                        cpu_mode           <= std_logic_vector(regs(17)(3 downto 0));
                        thumbmode          <= regs(17)(5);
                        FIQ_disable        <= regs(17)(6);
                        IRQ_disable        <= regs(17)(7);
                        Flag_Negative      <= regs(17)(31);
                        Flag_Zero          <= regs(17)(30);
                        Flag_Carry         <= regs(17)(29);
                        Flag_V_Overflow    <= regs(17)(28);
                        
                        if (regs(17)(5) = '1') then
                           new_pc     <= block_switch_pc(new_pc'left downto 1) & '0';
                        else
                           new_pc     <= block_switch_pc(new_pc'left downto 2) & "00";
                        end if;
                        
                        if (thumbmode = regs(17)(5)) then
                           execute_addcycles  <= 1 + codeticksAccess1632;
                           busPrefetchSub     <= '1';
                           prefetch_subcycles <= codeBaseAccess1632;
                           jump               <= '1';
                        else
                           branchnext         <= '1';
                        end if;

                  end case;
                  
               when software_interrupt_detail =>
                  if (execute_start = '1') then
                     if (thumbmode = '1') then
                        calc_result  <= execute_PCprev + 2;
                     else
                        calc_result  <= execute_PCprev + 4;
                     end if;
                     execute_writeback_calc <= '1';
                     writeback_reg          <= x"E";
                     
                     --if (old_IRQ_disable)  really required?
                     --{
                     --   regs[17] |= 0x80;
                     --}
                     
                     execute_saveState  <= '1';
                     execute_switchregs <= '1';
                     execute_saveregs   <= '1';
                     execute_SWI        <= '1';
                     cpu_mode_old       <= cpu_mode;
                     cpu_mode           <= CPUMODE_SUPERVISOR;
                     thumbmode          <= '0';
                     IRQ_disable        <= '1';
                     -- only switch for when not in system/usermode?
                     --FIQ_disable        <= regs(17)(6);
                     --Flag_Negative      <= regs(17)(31);
                     --Flag_Zero          <= regs(17)(30);
                     --Flag_Carry         <= regs(17)(29);
                     --Flag_V_Overflow    <= regs(17)(28);
                     new_pc             <= to_unsigned(8, new_pc'length);
                     branchnext         <= '1';
                  end if;
               
               when long_branch_with_link_low =>
                  if (execute_start = '1') then
                     new_pc                 <= (regs(14)(31 downto 1) & '0') + (execute_immidiate(10 downto 0) & '0');
                     branchnext             <= '1';
                     writeback_reg          <= x"E";
                     calc_result            <= execute_PC;
                     calc_result(0)         <= '1';
                     execute_writeback_calc <= '1';
                  end if;
               
            end case;
            
         end if;
         
      end if;
   
   end process;
   
   
   -- shifter
   process (clk100) 
   begin
      if (rising_edge(clk100)) then
   
         if (shifter_start = '1') then
            shiftervalue <= shiftreg;
      
            shift_rrx <= '0';
      
            if (execute_shiftsettings(0) = '0') then --shift by immidiate 
      
               shiftamount <= to_integer(unsigned(execute_shiftsettings(7 downto 3)));
               if ((execute_shiftsettings(2 downto 1) = "01" or execute_shiftsettings(2 downto 1) = "10") and execute_shiftsettings(7 downto 3) = "00000") then
                  shiftamount <= 32;
               end if;
               
               if (execute_shiftsettings(2 downto 1) = "11" and execute_shiftsettings(7 downto 3) = "00000") then
                  shift_rrx <= '1';
               end if;
      
            else --shift by register
               
               if (execute_Rm_op2 = x"F") then
                  shiftervalue <= shiftreg + 4; -- really always 4? not 2 for thumbmode?
               end if;
               
               if (execute_shiftsettings(2 downto 1) = "11" and unsigned(shiftbyreg) > 32) then
                  shiftamount <= to_integer(unsigned(shiftbyreg(4 downto 0)));
               else
                  shiftamount <= to_integer(unsigned(shiftbyreg));
               end if;
            
            end if;
         end if;
         
         -- ARM DOC: For all these instructions except ROR:
         -- if the shift is 32, Rd is cleared, and the last bit shifted out remains in the C flag
         -- if the shift is greater than 32, Rd and the C flag are cleared.
         --
         -- however this seems to be wrong. For asr setting rd to zero when shifting by 32 does not pass armwrestler tests
         
         -- LSL
         shiftresult_LSL <= shiftervalue;
         if (shiftamount >= 32) then
            if (shiftamount = 32) then
               shiftercarry_LSL <= shiftervalue(0);
            else
               shiftercarry_LSL <= '0';
            end if;
            shiftresult_LSL <= (others => '0');
         elsif (shiftamount > 0) then
            shiftercarry_LSL <= shiftervalue(32 - shiftamount);
            shiftresult_LSL <= shiftervalue sll shiftamount;
         else
            shiftercarry_LSL <= Flag_Carry;
         end if;
         
         -- RSL
         shiftresult_RSL <= shiftervalue;
         if (shiftamount >= 32) then
            if (shiftamount = 32) then
               shiftercarry_RSL <= shiftervalue(31);
            else
               shiftercarry_RSL <= '0';
            end if;
            shiftresult_RSL <= (others => '0');
         elsif (shiftamount > 0) then
            shiftercarry_RSL <= shiftervalue(shiftamount - 1);
            shiftresult_RSL <= shiftervalue srl shiftamount;
         else
            shiftercarry_RSL <= Flag_Carry;
         end if;
         
         -- ARS
         shiftresult_ARS <= shiftervalue;
         if (shiftamount >= 32) then
            shiftercarry_ARS <= shiftervalue(31);
            shiftresult_ARS <= unsigned(shift_right(signed(shiftervalue),31));
         elsif (shiftamount > 0)  then
            shiftercarry_ARS <= shiftervalue(shiftamount - 1);
            shiftresult_ARS <= unsigned(shift_right(signed(shiftervalue),shiftamount));
         else
            shiftercarry_ARS <= Flag_Carry;
         end if;
         
         -- ROR
         shiftresult_ROR <= shiftervalue;
         if (shiftamount >= 32) then -- >32 can never happen, as checked above, but this fixes simulation problems with carry index and other shifters
            shiftercarry_ROR <= shiftervalue(31);
         elsif (shiftamount > 0) then
            shiftercarry_ROR <= shiftervalue(shiftamount - 1); -- this is the critical line that should not be called if another shifter uses >32
            shiftresult_ROR  <= shiftervalue ror shiftamount;
         else
            shiftercarry_ROR <= Flag_Carry;
         end if;
         
         -- RRX
         shiftercarry_RRX <= shiftervalue(0);
         shiftresult_RRX  <= Flag_Carry & shiftervalue(31 downto 1);

         -- combine
         if (shift_rrx = '1') then
            shiftercarry <= shiftercarry_RRX;
            shiftresult  <= shiftresult_RRX;
         else
            case (execute_shiftsettings(2 downto 1)) is
               when "00" => shiftercarry <= shiftercarry_LSL; shiftresult <= shiftresult_LSL;
               when "01" => shiftercarry <= shiftercarry_RSL; shiftresult <= shiftresult_RSL;
               when "10" => shiftercarry <= shiftercarry_ARS; shiftresult <= shiftresult_ARS;
               when "11" => shiftercarry <= shiftercarry_ROR; shiftresult <= shiftresult_ROR;
               when others => null;
            end case;
         end if;
   
      end if;
   end process;
   
   
   
-- synthesis translate_off
   goutput : if is_simu = '1' generate
   begin
   
      process
      
         file outfile: text;
         file outfile_irp: text;
         variable f_status: FILE_OPEN_STATUS;
         variable line_out : line;
         variable recordcount : integer := 0;
         
         constant filenamebase               : string := "debug_gbasim";
         variable filename_current           : string(1 to 24);
         variable filename_pos               : integer;
         
         variable outsave_regs               : t_regs;
         variable outsave_opcode             : std_logic_vector(31 downto 0);
         variable outsave_Flag_Negative      : std_logic;
         variable outsave_Flag_Carry         : std_logic;
         variable outsave_Flag_Zero          : std_logic;
         variable outsave_Flag_V_Overflow    : std_logic;
         variable outsave_prefetch           : std_logic_vector(11 downto 0);
         variable outsave_thumbmode          : std_logic;
         variable outsave_cpumode            : std_logic_vector(3 downto 0);
         variable outsave_IRQ_disable        : std_logic;
         variable outsave_IRQFLAGs           : std_logic_vector(15 downto 0);
         
         variable outsave_timer0             : std_logic_vector(31 downto 0);
         variable outsave_timer1             : std_logic_vector(31 downto 0);
         variable outsave_timer2             : std_logic_vector(31 downto 0);
         variable outsave_timer3             : std_logic_vector(31 downto 0);
         variable outsave_memory1            : std_logic_vector(31 downto 0);
         variable outsave_memory2            : std_logic_vector(31 downto 0);
         variable outsave_memory3            : std_logic_vector(31 downto 0);
         variable outsave_dmatranscount      : std_logic_vector(31 downto 0);
         
         variable outsave_R13usr             : unsigned(31 downto 0);
         variable outsave_R14usr             : unsigned(31 downto 0);
         variable outsave_R13irq             : unsigned(31 downto 0);
         variable outsave_R14irq             : unsigned(31 downto 0);
         variable outsave_R13svc             : unsigned(31 downto 0);
         variable outsave_R14svc             : unsigned(31 downto 0);
         variable outsave_SPSR_irq           : unsigned(31 downto 0);
         variable outsave_SPSR_svc           : unsigned(31 downto 0);
         
         variable dma_new_cycles_1           : std_logic := '0';
         variable debug_dmatranfers          : unsigned(31 downto 0) := (others => '0');
         variable totalticks                 : unsigned(31 downto 0) := (others => '0');
         
         variable ignore_next                : std_logic := '0';
         
      begin
      
         filename_current := filenamebase & "00000000.txt";
   
         file_open(f_status, outfile, filename_current, write_mode);
         file_close(outfile);
         file_open(f_status, outfile, filename_current, append_mode);
         
         file_open(f_status, outfile_irp, "debug_gbasim_irp.txt", write_mode);
         file_close(outfile_irp);
         file_open(f_status, outfile_irp, "debug_gbasim_irp.txt", append_mode);
         
         write(line_out, string'("reg 00   reg 01   reg 02   reg 03   reg 04   reg 05   reg 06   reg 07   reg 08   reg 09   reg 10   reg 11   reg 12   reg 13   reg 14   reg 15   opcode   NCZV newticks PF  T Md I IFin T Timer0   Timer1   Timer2   Timer3   MEMORY01 MEMORY02 MEMORY03 DMATrans Reg 16   Reg 17   R13usr   R14usr   R13irq   R14irq   R13svc   R14svc   SPSR_irq SPSR_svc "));
         writeline(outfile, line_out);
         
         while (true) loop
            wait until rising_edge(clk100);
            
            if (gb_on = '1') then
               cyclecount <= cyclecount + 1;
            end if;
            
            if (dma_new_cycles = '1') then
               debug_dmatranfers := debug_dmatranfers + 1;
            end if;
            
            if (execute_IRP = '1') then
               write(line_out, to_hstring(to_unsigned(cyclenr, 32)));
               writeline(outfile_irp, line_out);
            end if;
            
            if (irq_calc = '1') then
               ignore_next := '1';
            end if;
            
            if (done = '1' and dma_new_cycles_1 = '0') then
               
               if (ignore_next = '1') then
               
                  ignore_next := '0';
               
               else

                  for i in 0 to 15 loop
                     write(line_out, to_hstring(outsave_regs(i)) & " ");
                  end loop;
                  
                  write(line_out, to_hstring(outsave_opcode) & " ");
                  
                  if (outsave_Flag_Negative = '1')   then write(line_out, string'("1"));  else write(line_out, string'("0")); end if;
                  if (outsave_Flag_Carry = '1')      then write(line_out, string'("1"));  else write(line_out, string'("0")); end if;
                  if (outsave_Flag_Zero = '1')       then write(line_out, string'("1"));  else write(line_out, string'("0")); end if;
                  if (outsave_Flag_V_Overflow = '1') then write(line_out, string'("1 ")); else write(line_out, string'("0 ")); end if;
                  
                  totalticks := totalticks + new_cycles_out;
                  write(line_out, to_hstring(totalticks) & " "); -- newticks
                  --write(line_out, "000000" & to_hstring(new_cycles_out) & " "); -- newticks
                  
                  write(line_out, to_hstring(outsave_prefetch) & " ");
                  
                  if (outsave_thumbmode = '1') then 
                     write(line_out, string'("1 "));
                  else
                     write(line_out, string'("0 "));
                  end if;
                  
                  write(line_out, "1" & to_hstring(outsave_cpumode) & " ");
                  
                  if (outsave_IRQ_disable = '1') then 
                     write(line_out, string'("1 "));
                  else
                     write(line_out, string'("0 "));
                  end if;
                  
                  write(line_out, to_hstring(IRP_in) & " ");
                  write(line_out, string'("0 ")); -- irp wait
                  
                  write(line_out, to_hstring(timerdebug0       ) & " "); -- timer
                  write(line_out, to_hstring(timerdebug1       ) & " "); -- timer
                  write(line_out, to_hstring(timerdebug2       ) & " "); -- timer
                  write(line_out, to_hstring(timerdebug3       ) & " "); -- timer 
                  
                  write(line_out, to_hstring(outsave_memory1      ) & " "); -- memory1
                  write(line_out, to_hstring(outsave_memory2      ) & " "); -- memory2
                  write(line_out, to_hstring(DISPSTAT_debug       ) & " "); -- memory3          
                  
                  write(line_out, to_hstring((debug_dmatranfers / 2)) & " "); -- dma trans count
                                                
                  write(line_out, to_hstring(outsave_regs(16)) & " ");
                  write(line_out, to_hstring(outsave_regs(17)) & " ");
                  
                  write(line_out, to_hstring(outsave_R13usr  ) & " "); -- R13usr
                  write(line_out, to_hstring(outsave_R14usr  ) & " "); -- R14usr                                         
                  write(line_out, to_hstring(outsave_R13irq  ) & " "); -- R13irq
                  write(line_out, to_hstring(outsave_R14irq  ) & " "); -- R14irq                                           
                  write(line_out, to_hstring(outsave_R13svc  ) & " "); -- R13svc
                  write(line_out, to_hstring(outsave_R14svc  ) & " "); -- R14svc                                           
                  write(line_out, to_hstring(outsave_SPSR_irq) & " "); -- SPSR_irq
                  write(line_out, to_hstring(outsave_SPSR_svc) & " "); -- SPSR_svc
                  
                  writeline(outfile, line_out);
                  
                  cyclenr     <= cyclenr + 1;
                  cyclesum    <= cyclesum + to_integer(new_cycles_out);
                  recordcount := recordcount + 1;
                  
                  if (cyclenr mod 1000000 = 0) then
                     filename_current := filenamebase & to_hstring(to_unsigned(cyclenr, 32)) & ".txt";
                     file_close(outfile);
                     file_open(f_status, outfile, filename_current, write_mode);
                     file_close(outfile);
                     file_open(f_status, outfile, filename_current, append_mode);
                     write(line_out, string'("reg 00   reg 01   reg 02   reg 03   reg 04   reg 05   reg 06   reg 07   reg 08   reg 09   reg 10   reg 11   reg 12   reg 13   reg 14   reg 15   opcode   NCZV newticks PF  T Md I IFin T Timer0   Timer1   Timer2   Timer3   MEMORY01 MEMORY02 MEMORY03 DMATrans Reg 16   Reg 17   R13usr   R14usr   R13irq   R14irq   R13svc   R14svc   SPSR_irq SPSR_svc "));
                     writeline(outfile, line_out);
                  end if;
                  
                  if (recordcount > 1000) then
                     file_close(outfile);
                     file_open(f_status, outfile, filename_current, append_mode);
                     file_close(outfile_irp);
                     file_open(f_status, outfile_irp, "debug_gbasim_irp.txt", append_mode);
                     recordcount := 0;
                  end if;
                  
               end if;
               
            end if;
               
            if (state_decode = DECODE_DONE and state_execute = FETCH_OP and do_step = '1' and dma_on = '0' and settle = '0' and halt = '0' and (irq_triggerhold = '0' or IRQ_disable = '1')) then
               for i in 0 to 17 loop
                  outsave_regs(i) := regs(i);
               end loop;
               outsave_regs(15) := decode_PC;

               if (thumbmode = '1') then
                  outsave_opcode := x"0000" & decode_data(15 downto 0);
               else
                  outsave_opcode := decode_data;
               end if;
               outsave_Flag_Negative   := Flag_Negative;
               outsave_Flag_Carry      := Flag_Carry;
               outsave_Flag_Zero       := Flag_Zero;
               outsave_Flag_V_Overflow := Flag_V_Overflow;

               outsave_prefetch := x"000";
               outsave_thumbmode := thumbmode;
               
               outsave_cpumode := cpu_mode;
               outsave_IRQ_disable := IRQ_disable; 

               outsave_IRQFLAGs := x"0000";
               
               outsave_timer0        := timerdebug0;
               outsave_timer1        := timerdebug1;
               outsave_timer2        := timerdebug2;
               outsave_timer3        := timerdebug3;                            
               outsave_memory1       := x"00000000"; -- memory
               outsave_memory2       := std_logic_vector(to_unsigned(debug_fifocount, 32));
               outsave_memory3       := x"00000000"; -- memory                        
               outsave_dmatranscount := x"00000000"; -- dma trans count      
               
               outsave_R13usr   := regs_0_13;
               outsave_R14usr   := regs_0_14;                                       
               outsave_R13irq   := regs_2_13;
               outsave_R14irq   := regs_2_14;                                      
               outsave_R13svc   := regs_3_13;
               outsave_R14svc   := regs_3_14;                                     
               outsave_SPSR_irq := regs_2_17;
               outsave_SPSR_svc := regs_3_17;
            end if;
            
            dma_new_cycles_1 := dma_new_cycles;
            
         end loop;
         
      end process;
      
   end generate goutput;
-- synthesis translate_on

end architecture;





