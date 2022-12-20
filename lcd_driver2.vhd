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

    type gen_mem is array (0 to 14) of unsigned(7 downto 0);
    signal send_mem : gen_mem;
    signal send_mem_idx : unsigned(7 downto 0);
    signal bytes_sent : unsigned(15 downto 0);
    signal lcd_wr_buf : std_logic;
    signal lcd_ready_buf : std_logic;

begin
    led2_debug<='0';
    led3_debug<=clk_in;
    lcd_d <= std_logic_vector(send_mem(conv_integer(send_mem_idx)));
    lcd_wr <= lcd_wr_buf;
    lcd_ready <= lcd_ready_buf;
    lcd_rst <= reset_in;

    send_mem(0) <= x"3a";
    send_mem(1) <= x"05";
    send_mem(2) <= x"2a";
    send_mem(7) <= x"2b";
    send_mem(12) <= x"2c";
    send_mem(13) <= color_array(conv_integer(color_in))(0);
    send_mem(14) <= color_array(conv_integer(color_in))(1);

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
        send_mem(3) <= start_col(15 downto 8);
        send_mem(4) <= start_col(7 downto 0);
        send_mem(5) <= end_col(15 downto 8);
        send_mem(6) <= end_col(7 downto 0);
        send_mem(8) <= start_page(15 downto 8);
        send_mem(9) <= start_page(7 downto 0);
        send_mem(10) <= end_page(15 downto 8);
        send_mem(11) <= end_page(7 downto 0);
    end process coord_set_proc;

    state_sync_proc: process(clk_in,reset_in)
    begin    
        if reset_in then
            send_mem_idx <= x"00";
            bytes_sent <= x"0000";
            PS <= IDLE;
        elsif rising_edge(clk_in) then
            if ((send_in = '1') and (PS = IDLE)) then
                send_mem_idx <= x"00";
                bytes_sent <= x"0000";
                PS <= LD;
            else
                if (PS = WR) then 
                    if (send_mem_idx = 14) then
                        bytes_sent <= bytes_sent + 1;
                        send_mem_idx <= conv_unsigned(13,8);
                    else
                        send_mem_idx <= send_mem_idx + 1;
                    end if;
                end if;
                PS <= NS;
            end if;
        end if;
    end process state_sync_proc;

    state_comb_proc: process(PS,bytes_sent,send_in)
    begin
        case PS is
            when LD =>
                led1_debug <= '1';
                lcd_wr_buf <= '0';
                lcd_ready_buf <= '0';
                if (bytes_sent >= conv_unsigned(400,16)) then
                    NS <= SPAM_STOP;
                else
                    NS <= WR;
                end if;

            when WR =>
                led1_debug <= '1';
                lcd_wr_buf <= '1';
                lcd_ready_buf <= '0';
                NS <= LD;

            when SPAM_STOP =>
                led1_debug <= '0';
                lcd_wr_buf <= '0';
                lcd_ready_buf <= '1';
                if (send_in = '1') then
                    NS <= SPAM_STOP;
                else
                    NS <= IDLE;
                end if;

            when others =>
                led1_debug <= '1';
                lcd_wr_buf <= '0';
                lcd_ready_buf <= '1';
                NS <= IDLE;
        end case;
    end process state_comb_proc;

    dcx_proc: process(send_mem_idx)
    begin
        case (conv_integer(send_mem_idx)) is
            when 0 => lcd_dcx <= '0';
            when 2 => lcd_dcx <= '0';
            when 7 => lcd_dcx <= '0';
            when 12 => lcd_dcx <= '0';
            when others => lcd_dcx <= '1';
        end case;
    end process dcx_proc;
    
-- architecture body
end architecture_lcd_driver4;


-- //Gamma Setting_10323
-- write_cmd(0xE0);
-- write_data8(0x0F);
-- write_data8(0x1B);
-- write_data8(0x18);
-- write_data8(0x0B);
-- write_data8(0x0E);
-- write_data8(0x09);
-- write_data8(0x47);
-- write_data8(0x94);
-- write_data8(0x35);
-- write_data8(0x0A);
-- write_data8(0x13);
-- write_data8(0x05);
-- write_data8(0x08);
-- write_data8(0x03);
-- write_data8(0x00);

-- write_cmd(0xE1);
-- write_data8(0x0F);
-- write_data8(0x3A);
-- write_data8(0x37);
-- write_data8(0x0B);

-- write_data8(0x0C);
-- write_data8(0x05);
-- write_data8(0x4A);
-- write_data8(0x24);

-- write_data8(0x39);
-- write_data8(0x07);
-- write_data8(0x10);
-- write_data8(0x04);

-- write_data8(0x27);
-- write_data8(0x25);
-- write_data8(0x00);
