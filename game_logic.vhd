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
   --Split RESET into RESET_LCD, RESET_GB, RESET_SNAKE, NEW_FOOD
   type state_type is (IDLE, RESET_LCD, RESET_GB, RESET_GB_SEND, RESET_SNAKE, RESET_SNAKE_SEND, 
                     MOVE_HEAD, SEND_HEAD, CHECK_HEAD, ERASE_TAIL, 
                     ADD_LENGTH, NEW_FOOD, NEW_FOOD_CHECK, NEW_FOOD_SEND, 
                     DELAY_INPUT, WIN, LOSE);
   signal PS : state_type;
   signal NS : state_type;
   
   signal time_since_start_of_cycle : integer;
   signal button_pressed : std_logic;

   signal setup_board_index : integer;
   
   type coord_type is array(0 to 1) of integer;
   type direction_list_type is array(0 to 3) of coord_type;
   constant UP : coord_type := (0,1);
   constant LEFT : coord_type := (-1,0);
   constant RIGHT : coord_type := (1,0);
   constant DOWN : coord_type := (0,-1);
   constant direction_list : direction_list_type := (UP,LEFT,DOWN,RIGHT);
   signal direction : coord_type;
   signal direction_changed : std_logic;
   signal reset_dir : std_logic;
   
   type snake_array_type is array(0 to max_snake_length-1) of coord_type;
   signal food_coord : coord_type;
   signal snake_array : snake_array_type;
   signal snake_length : integer;

   type snake_init_array_type is array(0 to 2) of coord_type;
   constant snake_init_array : snake_init_array_type := ((3,3),(3,2),(3,1));
begin
   button_pressed <= button_l xor button_r;

   sync_proc: process(clk_in,button_s)
   begin
   --If the reset button is hit, start the entire reset process.
   if (button_s = '1') then
      --TODO: Setup reset process
      setup_board_index <= -1;
      PS <= RESET_LCD;
   elsif rising_edge(clk_in) then
      
      if (PS = RESET_GB) then
         setup_board_index <= setup_board_index + 1;
         case expression is
            when choice =>
               
         
            when others =>
               
         
         end case;
      end if;

      if (PS = MOVE_HEAD) then
         --Shift the array to the right 
         snake_shift_loop: for i in 1 to snake_length loop
            snake_array(i+1) <= snake_array(i);
         end loop snake_shift_loop;
         --Calculate new head
         snake_array(0)(0) <= snake_array(0)(0) + direction(0);
         snake_array(0)(1) <= snake_array(0)(1) + direction(1);
      end if;

      if (PS = ADD_LENGTH) then
         snake_length <= snake_length + 1;
      end if;

      if (PS = DELAY_INPUT) then
         time_since_start_of_cycle <= time_since_start_of_cycle + 1;
      else
         time_since_start_of_cycle <= 0;
      end if;

      -- Only move to the next state if the lcd is finished drawing/setting up/etc.
      if (lcd_ready_in = '1') then
         PS <= NS;
      end if;
   end if;
   end process sync_proc;

   comb_proc : process(PS)
      variable snake_hit : std_logic := '0';
      variable food_hit : std_logic := '0';
   begin
      case PS is
         when IDLE =>
            send_draw_out <= '0';
            NS <= IDLE;
         when RESET_LCD =>
            send_draw_out <= '0';
            lcd_reset_out <= '1';
            NS <= RESET_GB;
         when RESET_GB =>
            send_draw_out <= '0';
            lcd_reset_out <= '0'; 
            NS <= RESET_GB_SEND;
         when RESET_GB_SEND =>
            send_draw_out <= '1';
            lcd_reset_out <= '0';
            NS <= RESET_GB;
         when RESET_SNAKE =>
            reset_dir <= '1';
            lcd_reset_out <= '0';
            NS <= RESET_SNAKE_SEND;
         when RESET_SNAKE_SEND =>
            send_draw_out <= '1';
            lcd_reset_out <= '0';
            NS <= RESET_GB;
            NS <= NEW_FOOD;
         when MOVE_HEAD =>
            reset_dir <= '0';
            direction_changed <= '0';
            send_draw_out <= '0';
            --Send new head to the draw output
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
            --Setup the coordinate output to erase the tail
            x_draw_out <= conv_unsigned(snake_array(snake_length-1)(0),8);
            y_draw_out <= conv_unsigned(snake_array(snake_length-1)(1),8);
            --Black, technically
            color_draw_out <= "11";

            --Check if there are collisions
            snake_hit := '0';
            snake_collision_check_loop : for i in 1 to snake_length-1 loop
               --TODO: Can we possibly forgo the latter statement?
               if (snake_array(0)(0) = snake_array(i)(0) and 
                  snake_array(0)(1) = snake_array(i)(1)) then
                  snake_hit := snake_hit or '1';
               else
                  snake_hit := snake_hit or '0';
               end if;
            end loop snake_collision_check_loop;

            --If on food, add length to the snake
            if (snake_array(0)(0) = food_coord(0) and snake_array(0)(1) = food_coord(1)) then
               NS <= ADD_LENGTH;
            --If out of bounds or collision, lose
            elsif (snake_array(0)(0) = 0 or 
                  snake_array(0)(0) = 23 or 
                  snake_array(0)(1) = 0 or 
                  snake_array(0)(1) = 15 or snake_hit = '1') then
               NS <= LOSE;
            --Else, nothing happened, erase the tail.
            else
               NS <= ERASE_TAIL;
            end if;

         when ERASE_TAIL =>
            send_draw_out <= '1';
            NS <= DELAY_INPUT;
         
         when ADD_LENGTH =>
            --Note: snake_length is incremented in the synchronous process.
            NS <= NEW_FOOD;

         when NEW_FOOD =>
            new_food_out <= '1';
            NS <= NEW_FOOD_CHECK;

         when NEW_FOOD_CHECK =>
            new_food_out <= '0';
            
            food_coord(0) <= conv_integer(food_x_in);
            food_coord(1) <= conv_integer(food_y_in);
            x_draw_out <= food_x_in;
            y_draw_out <= food_y_in;
            
            --Ensure the new food placement doesnt land on a snake part. Else, ask for a new one.
            food_hit := '0';
            food_collision_check_loop : for i in 0 to snake_length-1 loop
               if (conv_integer(food_x_in) = snake_array(i)(0) and 
                  conv_integer(food_y_in) = snake_array(i)(1)) then
                  food_hit := food_hit or '1';
               else
                  food_hit := food_hit or '0';
               end if;
            end loop food_collision_check_loop;

            if (food_hit = '1') then 
               NS <= NEW_FOOD;
            else
               NS <= NEW_FOOD_SEND;
            end if;

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

   direction_change_proc: process(PS,button_pressed,reset_dir)
   variable direction_idx : integer := 0;
   begin
      if (reset_dir = '1') then
         direction_idx := 0;
      elsif (rising_edge(button_pressed) and PS = DELAY_INPUT and direction_changed = '0') then 
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
