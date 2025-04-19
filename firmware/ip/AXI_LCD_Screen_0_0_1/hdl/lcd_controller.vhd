-- ============================================================================
-- File Name    : lcd_controller.vhd
-- Description  : This file contains the VHDL implementation of an LCD controller
--                that manages the initialization and operation of an LCD display.
-- Author       : Scott L. McKenzie
-- Created On   : 04/05/2025
-- Last Modified: 04/05/2025
-- Version      : 1.0
--
-- Copyright (C) 2025 Scott L. McKenzie. All rights reserved.
-- This file is subject to the terms and conditions defined in the
-- LICENSE file located in the root directory of this source code.
--
-- ============================================================================
-- Revision History:
-- Date        Author      Description
-- ----------- ----------- ---------------------------------------------------
-- 04/05/2025  Scott L. McKenzie    Initial creation of the file.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

use work.std_logic_vector_arrays.all;

entity lcd_controller is    
    generic(NUMBER_OF_LINES: integer range 1 to 2 := 2;             --Sets the number of lines on the LCD
            FONT_SIZE: integer range 8 to 11 := 11;                 --Sets the font size of the LCD
            CLK_FREQ: real range 100.0E6 to 250.0E6 := 100.0E6);     --Sets the clock frequency of the LCD
            --NUMBER_OF_BITS: integer range 4 to 8 := 8);
    port(LCD_CLK: in std_logic;
         RESETN: in std_logic;
         ENABLE: out std_logic;
         LCD_LINES: out std_logic_vector(9 downto 0);
         LINE_ONE: in slv_array(0 to 15)(7 downto 0);
         LINE_TWO: in slv_array(0 to 15)(7 downto 0));
end lcd_controller;

architecture synth_logic of lcd_controller is
    type lcd_statemachine_type is (POWER_ON, FUNCTION_SET1, FUNCTION_SET2, DISPLAY_ON, DISPLAY_CLEAR, ENTRY_MODE, RUN_MODE);
    signal lcd_state: lcd_statemachine_type := POWER_ON;

    --Internal signal used for output:
    signal lcd_out_init: std_logic_vector(LCD_LINES'range) := (others => '0');
    signal lcd_out_run: std_logic_vector(LCD_LINES'range) := (others => '0');

    --Internal signal used for pulsing the enable signal
    signal enable_strobe: std_logic := '0';
    signal enable_wire: std_logic_vector(1 downto 0) := (others => '0');
    signal enable_out: std_logic := '0';

    pure function generate_func_set_control_word(number_of_lines: integer; 
                                                font_size: integer) return std_logic_vector is
        variable control_word : std_logic_vector(7 downto 0) := (others => '0');
    begin
        -- Set bit 3 based on number_of_lines
        if(number_of_lines = 1) then
            control_word(3) := '0';
        else
            control_word(3) := '1';
        end if;

        -- Set bit 2 based on font_size
        if(font_size = 11) then
            control_word(2) := '1';
        elsif font_size = 8 then
            control_word(2) := '0';
        end if;

        return control_word;
    end function;

    constant POWER_ON_TIME: integer := integer(50.0E-3 * CLK_FREQ);      --40ms
    constant WAIT_TIME: integer := integer(40.0E-6 * CLK_FREQ);          --100us
    constant DISPLAY_CLEAR_TIME: integer := integer(1.8E-3 * CLK_FREQ);  --2ms
    constant SET_UP_TIME: integer := integer(80.0E-9 * CLK_FREQ);        --80ns
    constant HOLD_TIME: integer := integer(10.0E-9 * CLK_FREQ);          --10ns
    constant EN_HIGH_TIME: integer := integer(480.0E-9 * CLK_FREQ);      --460ns
    constant EN_LOW_TIME: integer := integer(740.0E-9 * CLK_FREQ);       --740ns
    constant FUNCTION_SET: std_logic_vector(LCD_LINES'high - 2 downto 0) := generate_func_set_control_word(NUMBER_OF_LINES, FONT_SIZE);
    constant DISPLAY_ON_SET: std_logic_vector(LCD_LINES'high - 2 downto 0) := X"0F";
    constant DISPLAY_CLEAR_SET: std_logic_vector(LCD_LINES'high - 2 downto 0) := X"01";
    constant ENTRY_MODE_SET: std_logic_vector(LCD_LINES'high - 2 downto 0) := X"07";
begin 
    --Assign internal lcd register to lcd_lines
    ENABLE <= enable_out;

    --lcd data lines out multiplexing
    with lcd_state select
        LCD_LINES <= lcd_out_run when RUN_MODE,
                     lcd_out_init when others;

    enable_strobe <= or_reduce(enable_wire);

    statemachine_proc: process(LCD_CLK, RESETN) is
        alias enable_strobe: std_logic is enable_wire(0);
        alias reg_select: std_logic is lcd_out_init(9);
        alias read_write: std_logic is lcd_out_init(8);
        alias data: std_logic_vector(7 downto 0) is lcd_out_init(7 downto 0);
        variable counter: integer := 0;
    begin
        if(RESETN = '0') then
            lcd_state <= POWER_ON;
            counter := 0;
            reg_select <= '0';
            read_write <= '0';
            data <= (others => '0');
        elsif(rising_edge(LCD_CLK)) then
            case lcd_state is
                when POWER_ON =>
                    if(counter = POWER_ON_TIME) then
                        counter := 0;
                        lcd_state <= FUNCTION_SET1;
                    elsif(counter = (POWER_ON_TIME - SET_UP_TIME)) then
                        data <= FUNCTION_SET;
                        lcd_state <= POWER_ON;
                    else
                        lcd_state <= POWER_ON;
                    end if; 
                    counter := counter + 1;  
                when FUNCTION_SET1 =>
                    if(counter = WAIT_TIME) then
                        counter := 0;
                        enable_strobe <= '0';
                        lcd_state <= FUNCTION_SET2;
                    else
                        enable_strobe <= '1';
                        lcd_state <= FUNCTION_SET1;
                    end if;
                    counter := counter + 1;
                when FUNCTION_SET2 =>
                    if(counter = WAIT_TIME) then
                        counter := 0;
                        enable_strobe <= '0';
                        lcd_state <= DISPLAY_ON;
                    elsif(counter = (WAIT_TIME - SET_UP_TIME)) then
                        data <= DISPLAY_ON_SET;
                        lcd_state <= FUNCTION_SET2;
                    else
                        enable_strobe <= '1';
                        lcd_state <= FUNCTION_SET2;
                    end if;
                    counter := counter + 1;
                when DISPLAY_ON =>
                    if(counter = WAIT_TIME) then
                        counter := 0;
                        enable_strobe <= '0';
                        lcd_state <= DISPLAY_CLEAR;
                    elsif(counter = (WAIT_TIME - SET_UP_TIME)) then
                        data <= DISPLAY_CLEAR_SET;
                        lcd_state <= DISPLAY_ON;
                    else
                        enable_strobe <= '1';
                        lcd_state <= DISPLAY_ON;
                    end if;
                    counter := counter + 1;
                when DISPLAY_CLEAR =>
                    if(counter = DISPLAY_CLEAR_TIME) then
                        counter := 0;
                        enable_strobe <= '0';
                        lcd_state <= ENTRY_MODE;
                    elsif(counter = (DISPLAY_CLEAR_TIME - SET_UP_TIME)) then
                        data <= ENTRY_MODE_SET;
                        lcd_state <= DISPLAY_CLEAR;
                    else
                        enable_strobe <= '1';
                        lcd_state <= DISPLAY_CLEAR;
                    end if;
                    counter := counter + 1;
                when ENTRY_MODE =>
                    if(counter = (EN_HIGH_TIME + EN_LOW_TIME)) then
                        counter := 0;
                        enable_strobe <= '0';
                        lcd_state <= RUN_MODE;
                    else
                        enable_strobe <= '1';
                        lcd_state <= ENTRY_MODE;
                    end if;
                    counter := counter + 1;
                when others => --RUN_MODE
                    lcd_state <= RUN_MODE;
            end case; 
        end if;
    end process statemachine_proc;

    enable_pulse_proc: process(LCD_CLK) is
        variable enable_strobe_prev: std_logic := '0';
        variable counter: integer := 0;
    begin
        if(rising_edge(LCD_CLK)) then
            if(enable_strobe = '1' and enable_strobe_prev = '0') then
                counter := 1;
                enable_out <= '1';
            elsif(counter > 0) then 
                if(counter = EN_HIGH_TIME) then
                    enable_out <= '0';
                end if; 
                counter := counter + 1;
            else
                counter := 0; 
            end if;
            enable_strobe_prev := enable_strobe;
        end if; 
    end process enable_pulse_proc; 

end synth_logic;
