--------------------------------------------------------------------------------
-- Company: <Name>
--
-- File: random_food_gen.vhd
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
use IEEE.numeric_std.all;

entity random_food_gen is
port (
    --<port_name> : <direction> <type>;
    new_in : IN std_logic;
    
    x_out : OUT  unsigned(7 downto 0);
    y_out : OUT  unsigned(7 downto 0)
    --<other_ports>;
);
end random_food_gen;
architecture architecture_random_food_gen of random_food_gen is
   -- signal, component etc. declarations
	signal signal_name1 : std_logic; -- example
	signal signal_name2 : std_logic_vector(1 downto 0) ; -- example

begin

   -- architecture body
end architecture_random_food_gen;
