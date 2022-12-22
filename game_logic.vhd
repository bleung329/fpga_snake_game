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
generic (
   time_to_wait : integer := 500000;
   max_snake_length : integer := 20
);
port (
    --<port_name> : <direction> <type>;
    button_l, button_r, button_s : IN std_logic;
    lcd_ready_in : IN  std_logic;
    clk_in : IN std_logic;

    food_x_in : IN unsigned(7 downto 0);
    food_y_in : IN unsigned(7 downto 0);

    x_draw_out : OUT   unsigned(7 downto 0) := x"00";
    y_draw_out : OUT   unsigned(7 downto 0) := x"00";
    color_draw_out : OUT unsigned(1 downto 0);
    send_draw_out : OUT std_logic;
    lcd_reset_out : OUT std_logic;
    new_food_out : OUT std_logic
);
end game_logic;

architecture architecture_game_logic of game_logic is
   type state_type is (IDLE, RESET_LOAD, RESET_SEND, 
                     MOVE_HEAD, SEND_HEAD, CHECK_HEAD, ERASE_TAIL, 
                     NEW_FOOD, NEW_FOOD_CHECK, NEW_FOOD_SEND, 
                     DELAY_INPUT, WIN, LOSE);
   signal PS : state_type;
   signal NS : state_type;
   
   signal time_since_start_of_cycle : integer;
   signal button_pressed : std_logic;
   
   type coord_type is array(0 to 1) of integer;
   type direction_list_type is array(0 to 3) of coord_type;
   constant UP : coord_type := (0,1);
   constant LEFT : coord_type := (-1,0);
   constant RIGHT : coord_type := (1,0);
   constant DOWN : coord_type := (0,-1);
   constant direction_list : direction_list_type := (UP,LEFT,DOWN,RIGHT);
   signal direction : coord_type;
   signal direction_changed : std_logic;
   
   type snake_array_type is array(0 to max_snake_length-1) of coord_type;
   signal food_coord : coord_type;
   signal snake_array : snake_array_type;
   signal snake_length : integer;

begin
   button_pressed <= button_l xor button_r;

   sync_proc: process(clk_in,button_s)
   begin
   --If the reset button is hit, start the entire reset process.
   if (button_s = '1') then
      PS <= RESET_LOAD;
   elsif rising_edge(clk_in) then
      
      if (PS = MOVE_HEAD) then
         --Shift the array to the right 
         shift_loop: for i in 1 to snake_length loop
            snake_array(i+1) <= snake_array(i);
         end loop shift_loop;
         --Calculate new head
         snake_array(0)(0) <= snake_array(0)(0) + direction(0);
         snake_array(0)(1) <= snake_array(0)(1) + direction(1);
      end if;

      if (PS = DELAY_INPUT) then
         time_since_start_of_cycle <= time_since_start_of_cycle + 1;
      else
         time_since_start_of_cycle <= 0;
      end if;

      -- Only move to the next state if the lcd is finished drawing/setting up/etc.
      if (lcd_ready_in = '1') then
         PS <= NS;
         --Do nothing
      end if;
   end if;
   end process sync_proc;

   comb_proc : process(PS)
      variable snake_hit : std_logic := '0';
   begin
      case PS is
         when IDLE =>
            send_draw_out <= '0';
            NS <= IDLE;    
         when RESET_LOAD =>
            send_draw_out <= '0';
            NS <= RESET_SEND;
         when RESET_SEND =>
            send_draw_out <= '1';
            NS <= RESET_LOAD;
         when MOVE_HEAD =>
            direction_changed <= '0';
            send_draw_out <= '0';
            --Send new head to the 
            x_draw_out <= conv_unsigned(snake_array(0)(0),8);
            y_draw_out <= conv_unsigned(snake_array(0)(1),8);
            -- Draw it green
            color_draw_out <= "01";
            NS <= SEND_HEAD;
         when SEND_HEAD =>
            send_draw_out <= '1';
            NS <= CHECK_HEAD;
         when CHECK_HEAD =>
            send_draw_out <= '0';
            --Setup the thing to erase the tail
            x_draw_out <= conv_unsigned(snake_array(snake_length-1)(0),8);
            y_draw_out <= conv_unsigned(snake_array(snake_length-1)(1),8);
            color_draw_out <= "11";

            --Check if there are collisions
            for i in 1 to snake_length loop
               if (snake_array(0)(0) = snake_array(i)(0) and 
                  snake_array(0)(1) = snake_array(i)(1)) then
                  snake_hit := snake_hit or '1';
               else
                  snake_hit := snake_hit or '0';
               end if;
            end loop;

            --If on food,
            if (snake_array(0)(0) = food_coord(0) and snake_array(0)(1) = food_coord(1)) then
               NS <= NEW_FOOD;
            --Out of bounds and collision
            elsif (snake_array(0)(0) = 0 or 
                  snake_array(0)(0) = 23 or 
                  snake_array(0)(1) = 0 or 
                  snake_array(0)(1) = 15 or snake_hit = '1') then
               NS <= LOSE;
            --Nothing happened, erase the tail.
            else
               NS <= ERASE_TAIL;
            end if;
         when ERASE_TAIL =>
            send_draw_out <= '1';
            NS <= DELAY_INPUT;
         when NEW_FOOD =>
            new_food_out <= '1';
            NS <= NEW_FOOD_CHECK;
         when NEW_FOOD_CHECK =>
            new_food_out <= '0';
            food_coord(0) <= conv_integer(food_x_in);
            food_coord(1) <= conv_integer(food_y_in);
            x_draw_out <= food_x_in;
            y_draw_out <= food_y_in;
            NS <= NEW_FOOD;
         when NEW_FOOD_SEND =>
            send_draw_out <= '1';
            NS <= DELAY_INPUT;
         when DELAY_INPUT =>
            send_draw_out <= '0';
            if (time_since_start_of_cycle > time_to_wait) then
               NS <= MOVE_HEAD;
            else
               NS <= DELAY_INPUT;
            end if;
         when WIN =>
            NS<=IDLE;
         when LOSE =>
            NS<=IDLE;
         when others =>
            send_draw_out <= '0';
            NS <= IDLE;
      end case;
   end process comb_proc;

   direction_change_proc: process(PS,button_pressed)
   variable direction_idx : integer := 0;
   begin
      if (rising_edge(button_pressed) and PS = DELAY_INPUT and direction_changed = '0') then 
         if (button_r = '1') then
            direction_idx := direction_idx + 1;
            if (direction_idx > 3) then
               direction_idx := 0;
            end if;
         elsif (button_l = '1') then
            direction_idx := direction_idx - 1;
            if (direction_idx < 0) then
               direction_idx := 3;
            end if;
         end if;
         direction_changed <= '1';
      end if;
      direction <= direction_list(direction_idx);
   end process direction_change_proc;

end architecture_game_logic;
