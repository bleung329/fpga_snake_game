--------------------------------------------------------------------------------
-- Company: 
--
-- File: storage_thingy.vhd
-- File history:
--      <Revision number>: <Date>: <Comments>
--      <Revision number>: <Date>: <Comments>
--      <Revision number>: <Date>: <Comments>
--
-- Description: 
--
-- Absolutely disgusting
--
-- Targeted device: <Family::SmartFusion2> <Die::M2S010> <Package::256 VF>
-- Author: <Name>
--
--------------------------------------------------------------------------------

library IEEE;

use IEEE.std_logic_1164.all;    
use IEEE.std_logic_arith.all;

entity lcd_driver4 is
generic (
    g_init_instructions : integer := 6;
    g_clk_div : integer := 50000
);
port (
    x_in : IN unsigned(7 downto 0);
    y_in : IN unsigned(7 downto 0);
    color_in : IN unsigned(1 downto 0);
    send_in : IN std_logic;
    clk_in : IN std_logic;
    reset_in : IN std_logic;
    
    lcd_ready : OUT std_logic := '1';
    lcd_d : OUT std_logic_vector(7 downto 0);
    lcd_dcx : OUT std_logic := '0';
    lcd_wr : OUT std_logic := '0';
    lcd_rst : OUT std_logic;
    led1_debug : OUT std_logic;
    led2_debug : OUT std_logic;
    led3_debug : OUT std_logic
);
end entity lcd_driver4;

architecture architecture_lcd_driver4 of lcd_driver4 is

    type state_type is (IDLE,LD,WR,SPAM_STOP,LD_INIT,WR_INIT);
    signal PS : state_type;
    signal NS : state_type;

    type color_bytes is array (0 to 1) of unsigned(7 downto 0);
    constant RED : color_bytes := ("11111000","00000000");
    constant GREEN : color_bytes := ("00000111","11100000");
    constant BLUE : color_bytes := ("00000000","00011111");
    constant WHITE : color_bytes := ("00000000","00000000");

    type color_array_type is array (0 to 3) of color_bytes;
    constant color_array : color_array_type := (
        RED, GREEN, BLUE, WHITE
    );

    type mem_piece is array(0 to 1) of unsigned(7 downto 0);
    type init_rom is array(0 to g_init_instructions) of mem_piece;
    constant init_mem : init_rom := ((x"01",x"00"),
                                    (x"11",x"00"),
                                    (x"3a",x"00"),
                                    (x"55",x"01"),
                                    (x"29",x"00"),
                                    (x"00",x"00"),
                                    (x"00",x"00"));

    type pixel_mem is array (0 to 12) of mem_piece;
    signal send_mem : pixel_mem;
    signal send_mem_idx : unsigned(7 downto 0);
    signal bytes_sent : unsigned(15 downto 0);
    signal lcd_wr_buf : std_logic;
    signal lcd_ready_buf : std_logic;
    signal slow_clk_sel : std_logic;
    signal slow_clk : std_logic;
    signal sig_clk_in : std_logic;

begin
    -- led2_debug <= '0';
    -- led3_debug <= clk_in;
    lcd_wr <= lcd_wr_buf;
    lcd_ready <= lcd_ready_buf;
    lcd_rst <= reset_in;

    send_mem(0) <= (x"2a",x"00");
    send_mem(5) <= (x"2b",x"00");
    send_mem(10) <= (x"2c",x"00");
    send_mem(11) <= (color_array(conv_integer(color_in))(0),x"01");
    send_mem(12) <= (color_array(conv_integer(color_in))(1),x"01");

    coord_set_proc: process(x_in,y_in)
        variable start_col : unsigned(15 downto 0) := x"0000";
        variable end_col : unsigned(15 downto 0) := x"0000";
        variable start_page : unsigned(15 downto 0) := x"0000";
        variable end_page : unsigned(15 downto 0) := x"0000";
    begin
        start_col := x_in * conv_unsigned(20,8);
        end_col := start_col + 20;
        start_page := y_in * conv_unsigned(20,8);
        end_page := start_page + 20;
        send_mem(1) <= (start_col(15 downto 8),x"01");
        send_mem(2) <= (start_col(7 downto 0),x"01");
        send_mem(3) <= (end_col(15 downto 8),x"01");
        send_mem(4) <= (end_col(7 downto 0),x"01");
        send_mem(6) <= (start_page(15 downto 8),x"01");
        send_mem(7) <= (start_page(7 downto 0),x"01");
        send_mem(8) <= (end_page(15 downto 8),x"01");
        send_mem(9) <= (end_page(7 downto 0),x"01");
    end process coord_set_proc;

    --A cute little clock divider/selector
    with slow_clk_sel select
        sig_clk_in <= clk_in when '0', slow_clk when others;

    clk_maker_proc: process(clk_in)
        variable clk_counter : integer;
    begin
        if rising_edge(clk_in) then
            clk_counter := clk_counter + 1;
            if (clk_counter > g_clk_div) then
                slow_clk <= not slow_clk;
            end if;
        end if;
    end process clk_maker_proc;

    state_sync_proc: process(sig_clk_in,reset_in,PS)
    begin    
        if (reset_in = '1' and PS /= SPAM_STOP) then
            -- Start the startup sequence and swap the clock to the super slow one. Switch it back when you're done.
            send_mem_idx <= x"00";
            PS <= LD_INIT;
        elsif rising_edge(sig_clk_in) then
            if ((send_in = '1') and (PS = IDLE)) then
                send_mem_idx <= x"00";
                bytes_sent <= x"0000";
                PS <= LD;
            else
                if (PS = WR) then 
                    if (send_mem_idx = 12) then
                        bytes_sent <= bytes_sent + 1;
                        send_mem_idx <= conv_unsigned(11,8);
                    else
                        send_mem_idx <= send_mem_idx + 1;
                    end if;
                end if;
                
                if (PS = WR_INIT) then
                    send_mem_idx <= send_mem_idx + 1;
                end if;

                PS <= NS;
            end if;
        end if;
    end process state_sync_proc;

    state_comb_proc: process(PS,bytes_sent,send_in,send_mem,send_mem_idx,reset_in)
        variable sm_idx : integer;
    begin
        -- Just saves me some typing
        sm_idx := conv_integer(send_mem_idx);
        case PS is
            when LD =>
                slow_clk_sel <= '0';
                lcd_d <= std_logic_vector(send_mem(sm_idx)(0));
                lcd_dcx <= std_logic(send_mem(sm_idx)(1)(0));
                led1_debug <= '0';
                led2_debug <= '1';
                led3_debug <= '1';
                lcd_wr_buf <= '0';
                lcd_ready_buf <= '0';
                if (bytes_sent >= conv_unsigned(400,16)) then
                    NS <= SPAM_STOP;
                else
                    NS <= WR;
                end if;

            when WR =>
                slow_clk_sel <= '0';
                lcd_d <= std_logic_vector(send_mem(sm_idx)(0));
                lcd_dcx <= std_logic(send_mem(sm_idx)(1)(0));
                led1_debug <= '0';
                led2_debug <= '1';
                led3_debug <= '1';
                lcd_wr_buf <= '1';
                lcd_ready_buf <= '0';
                NS <= LD;
                
            when SPAM_STOP =>
                slow_clk_sel <= '0';
                lcd_d <= x"00";
                lcd_dcx <= '0';
                led1_debug <= '1';
                led2_debug <= '0';
                led3_debug <= '1';
                lcd_wr_buf <= '0';
                lcd_ready_buf <= '1';
                if (send_in = '1' or reset_in = '1') then
                    NS <= SPAM_STOP;
                else
                    NS <= IDLE;
                end if;

            when LD_INIT =>
                slow_clk_sel <= '1';
                lcd_d <= std_logic_vector(init_mem(sm_idx)(0));
                lcd_dcx <= std_logic(init_mem(sm_idx)(1)(0));
                led1_debug <= '1';
                led2_debug <= '1';
                led3_debug <= '0';
                lcd_wr_buf <= '0';
                lcd_ready_buf <= '0';
                if (sm_idx >= g_init_instructions) then
                    NS <= SPAM_STOP;
                else
                    NS <= WR_INIT;
                end if;
                
            when WR_INIT =>
                slow_clk_sel <= '1';
                lcd_d <= std_logic_vector(init_mem(sm_idx)(0));
                lcd_dcx <= std_logic(init_mem(sm_idx)(1)(0));
                led1_debug <= '1';
                led2_debug <= '1';
                led3_debug <= '0';
                lcd_wr_buf <= '1';
                lcd_ready_buf <= '0';
                NS <= LD_INIT;
                
            when others =>
                slow_clk_sel <= '0';
                lcd_d <= x"00";
                lcd_dcx <= '0';
                led1_debug <= '1';
                led2_debug <= '1';
                led3_debug <= '1';
                lcd_wr_buf <= '0';
                lcd_ready_buf <= '1';
                NS <= IDLE;
        end case;
    end process state_comb_proc;
    
-- architecture body
end architecture_lcd_driver4;