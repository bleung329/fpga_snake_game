--------------------------------------------------------------------------------
-- Company: <Name>
--
-- File: game_logic.vhd
-- File history:
--      <Revision number>: <Date>: <Comments>
--      <Revision number>: <Date>: <Comments>
--      <Revision number>: <Date>: <Comments>
--
-- Description: 
--
-- <Description here>
--
-- Targeted device: <Family::SmartFusion2> <Die::M2S010> <Package::256 VF>
-- Author: <Name>
--
--------------------------------------------------------------------------------

library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;

entity game_logic is
port (
    --<port_name> : <direction> <type>;
    button_l, button_r, button_s : IN std_logic;
    lcd_ready : IN  std_logic;

    food_coord_x : IN unsigned(7 downto 0);
    food_coord_y : IN unsigned(7 downto 0);

    x_out : OUT   unsigned(7 downto 0) := x"00";
    y_out : OUT   unsigned(7 downto 0) := x"00";
    color_out : OUT unsigned(1 downto 0) := x"1";
    send_out : OUT std_logic := '0';
    new_food_out : OUT std_logic
);
end game_logic;
architecture architecture_game_logic of game_logic is
   
begin
   send_out <= button_l;
   x_out <= x"01";
   y_out <= x"02";
   color_out <= x"1";
end architecture_game_logic;
