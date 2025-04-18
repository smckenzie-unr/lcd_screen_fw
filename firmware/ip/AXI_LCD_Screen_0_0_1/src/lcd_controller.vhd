library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

use work.std_logic_vector_arrays.all;

-- ============================================================================
-- Entity: lcd_controller
-- Description: This entity represents a controller for an LCD screen. It is 
--              designed to handle the communication and control signals 
--              required to interface with an LCD display.
--
-- Generics:
--   NUMBER_OF_LINES       : integer range 1 to 2 := 2
--                           Specifies the number of lines on the LCD screen 
--                           (1 or 2 lines).
--   FONT_SIZE             : integer range 8 to 11 := 11
--                           Defines the font size used on the LCD screen 
--                           (in pixels).
--   CLK_FREQ              : real range 50.0E6 to 250.0E6 := 100.0E6
--                           Specifies the clock frequency in Hz for the LCD 
--                           controller.
--   NUMBER_OF_BITS        : integer range 4 to 8 := 8
--                           Determines the number of data lines used for 
--                           communication with the LCD (4-bit or 8-bit mode).
--   ENABLE_PULSE_WIDTH    : real range 1.0E-6 to 10.0E-6 := 1.0E-6
--                           Specifies the pulse width of the ENABLE signal 
--                           in seconds.
--
-- Ports:
--   LCD_CLK               : in std_logic
--                           Input clock signal for the LCD controller.
--   ENABLE                : out std_logic
--                           Output signal to enable the LCD for data 
--                           transmission.
--   REG_SELECT            : out std_logic
--                           Output signal to select between instruction 
--                           register and data register.
--   READ_WRITE            : out std_logic
--                           Output signal to control read/write operations 
--                           (read = '1', write = '0').
--   LCD_DATA_LINES        : out std_logic_vector(NUMBER_OF_BITS - 1 downto 0)
--                           Output data lines for communication with the LCD.
--   LINE_ONE_DATA         : in slv_array(0 to 15)(7 downto 0)
--                           Input data for the first line of the LCD screen 
--                           (16 characters, 8 bits each).
--   LINE_TWO_DATA         : in slv_array(0 to 15)(7 downto 0)
--                           Input data for the second line of the LCD screen 
--                           (16 characters, 8 bits each).
-- ============================================================================
entity lcd_controller is
    generic(NUMBER_OF_LINES: integer range 1 to 2 := 2;
            FONT_SIZE: integer range 8 to 11 := 11;
            CLK_FREQ: real range 50.0E6 to 250.0E6 := 100.0E6;
            NUMBER_OF_BITS: integer range 4 to 8 := 8;
            ENABLE_PULSE_WIDTH: real range 1.0E-6 to 10.0E-6 := 1.0E-6);
    port(LCD_CLK: in std_logic;
         ENABLE: out std_logic;
         REG_SELECT: out std_logic;
         READ_WRITE: out std_logic;
         LCD_DATA_LINES: out std_logic_vector(NUMBER_OF_BITS - 1 downto 0);
         LINE_ONE_DATA: in slv_array(0 to 15)(7 downto 0);
         LINE_TWO_DATA: in slv_array(0 to 15)(7 downto 0));
end lcd_controller;

architecture synth_logic of lcd_controller is

-- ============================================================================
-- Function: init_function_set
-- ----------------------------------------------------------------------------
-- Description:
-- This pure function initializes the function set configuration for an LCD 
-- controller. It generates a `std_logic_vector` that represents the function 
-- set command based on the number of display lines and font size.
--
-- Parameters:
-- - NUM_LINES: Integer specifying the number of display lines for the LCD.
--              Typically, 1 for single-line displays and 2 for two-line displays.
-- - FONT_SIZE: Integer specifying the font size. Common values are:
--              - 8: Small font size
--              - 11: Large font size
--
-- Returns:
-- - A `std_logic_vector` representing the function set command for the LCD.
--
-- Internal Details:
-- - The `function_set` variable is initialized to a default value of X"30".
-- - Aliases `set_num_lines` and `set_font_size` are used to modify specific 
--   bits of the `function_set` vector based on the input parameters.
-- - The `with ... select` construct is used to assign values to the aliases 
--   based on the `NUM_LINES` and `FONT_SIZE` parameters.
-- ============================================================================
     pure function init_function_set(NUM_LINES: integer; FONT_SIZE: integer) return std_logic_vector is
        variable function_set: std_logic_vector(NUMBER_OF_BITS - 1 downto 0) := X"30";
        alias set_num_lines: std_logic is function_set(3);
        alias set_font_size: std_logic is function_set(2);
     begin
        with NUMBER_OF_BITS select
           set_num_lines := '1' when 1,
                            '0' when 2;
        with FONT_SIZE select
           set_font_size := '0' when 8,
                            '1' when 11,
                            '0' when others;
        return function_set;
     end function;

     constant PULSE_WDITH: integer := integer(ENABLE_PULSE_WIDTH * CLK_FREQ);

     type main_lcd_statemachine is (POWER_UP, FUNCTION_SET, DISPLAY_CONTROL, DISPLAY_CLEAR, ENTRY_MODE_SET, RUN_MODE);
     signal current_lcd_state: main_lcd_statemachine := POWER_UP;

     signal enable_out: std_logic;
     signal en_wire: std_logic_vector(1 downto 0);
     alias run_mode_enable: std_logic is en_wire(0);
     alias init_mode_enable: std_logic is en_wire(1);

     signal rs_signal : std_logic_vector(1 downto 0);
     alias run_mode_rs : std_logic is rs_signal(0);
     alias init_mode_rs : std_logic is rs_signal(1);

     signal rw_signal : std_logic_vector(1 downto 0);
     alias run_mode_rw : std_logic is rw_signal(0);
     alias init_mode_rw : std_logic is rw_signal(1);

     signal data_signal : std_logic_vector((NUMBER_OF_BITS * 2) - 1 downto 0);
     alias run_mode_data : std_logic_vector(NUMBER_OF_BITS - 1 downto 0) is data_signal(NUMBER_OF_BITS - 1 downto 0);
     alias init_mode_data : std_logic_vector(NUMBER_OF_BITS - 1 downto 0) is data_signal((NUMBER_OF_BITS * 2) - 1 downto NUMBER_OF_BITS);
begin 
     enable_out <= or_reduce(en_wire);
     REG_SELECT <= or_reduce(rs_signal);
     READ_WRITE <= or_reduce(rw_signal);
     with current_lcd_state select
        LCD_DATA_LINES <= run_mode_data when RUN_MODE,
                          init_mode_data when others;

-- ============================================================================
-- Process Name: main_statemachine_proc
-- Description : Implements the main state machine for controlling the LCD.
--               This process handles the initialization sequence and transitions
--               between various states required to configure and operate the LCD.
-- 
-- Clock       : LCD_CLK
-- 
-- Constants:
--   - POWER_ON_TIME        : Time required for the LCD to power up, calculated
--                            based on the clock frequency (40ms).
--   - FUNCTION_SET_TIME    : Time required for the function set command, calculated
--                            based on the clock frequency (37µs).
--   - DISPLAY_CLEAR_TIME   : Time required for the display clear command, calculated
--                            based on the clock frequency (1.53ms).
--   - function_set_slv     : Precomputed function set command based on the number
--                            of lines and font size.
--   - display_control_slv  : Predefined display control command (0x0F).
-- 
-- Variable:
--   - counter              : Tracks the elapsed time or cycles within each state.
-- 
-- States:
--   - POWER_UP             : Waits for the LCD to power up. Transitions to FUNCTION_SET
--                            after POWER_ON_TIME cycles.
--   - FUNCTION_SET         : Sends the function set command to the LCD. Transitions
--                            to DISPLAY_CONTROL after the required time.
--   - DISPLAY_CONTROL      : Sends the display control command to the LCD. Transitions
--                            to DISPLAY_CLEAR after the required time.
--   - DISPLAY_CLEAR        : Sends the display clear command to the LCD. Transitions
--                            to ENTRY_MODE_SET after the required time.
--   - ENTRY_MODE_SET       : Sends the entry mode set command to the LCD. Transitions
--                            to RUN_MODE after the required time.
--   - RUN_MODE             : Final operational state of the LCD.
-- 
-- Notes:
--   - The process uses a counter to manage timing for each state.
--   - The init_mode_* signals are used to send commands and control signals to the LCD.
--   - The state machine ensures proper sequencing of initialization commands as per
--     the LCD's datasheet requirements.
-- ============================================================================
     main_statemachine_proc: process(LCD_CLK) is
        constant POWER_ON_TIME: integer := integer(40.0E-3 * CLK_FREQ);
        constant FUNCTION_SET_TIME: integer := integer(37.0E-6 * CLK_FREQ);
        constant DISPLAY_CLEAR_TIME: integer := integer(1.53E-3 * CLK_FREQ);
        constant function_set_slv : std_logic_vector(NUMBER_OF_BITS - 1 downto 0) := init_function_set(NUMBER_OF_LINES, FONT_SIZE);
        constant display_control_slv : std_logic_vector(NUMBER_OF_BITS - 1 downto 0) := X"0F";
        variable counter: integer := 0;
     begin
        if(rising_edge(LCD_CLK)) then
            case current_lcd_state is
                when POWER_UP =>
                    counter := counter + 1;
                    if(counter = POWER_ON_TIME) then
                        current_lcd_state <= FUNCTION_SET;
                        counter := 0;
                    else
                        current_lcd_state <= POWER_UP;
                    end if;
                when FUNCTION_SET =>
                    init_mode_data <= function_set_slv;
                    init_mode_rs <= '0';
                    init_mode_rw <= '0';
                    if(counter = 0 or counter = FUNCTION_SET_TIME) then
                        init_mode_enable <= '1';
                        current_lcd_state <= FUNCTION_SET;
                    elsif(counter = 2 * FUNCTION_SET_TIME) then
                        current_lcd_state <= DISPLAY_CONTROL;
                        counter := 0;
                    else
                        current_lcd_state <= FUNCTION_SET;
                        init_mode_enable <= '0';
                    end if;
                    counter := counter + 1;
                when DISPLAY_CONTROL =>
                    init_mode_data <= display_control_slv;
                    init_mode_rs <= '0';
                    init_mode_rw <= '0';
                    if(counter = 0) then 
                        init_mode_enable <= '1';
                        current_lcd_state <= DISPLAY_CONTROL;
                    elsif(counter = FUNCTION_SET_TIME) then
                        current_lcd_state <= DISPLAY_CLEAR;
                        counter := 0;
                    else
                        current_lcd_state <= DISPLAY_CONTROL;
                        init_mode_enable <= '0';
                    end if;
                    counter := counter + 1;
                when DISPLAY_CLEAR =>
                    init_mode_data <= X"01";
                    init_mode_rs <= '0';
                    init_mode_rw <= '0';
                    if(counter = 0) then 
                        init_mode_enable <= '1';
                        current_lcd_state <= DISPLAY_CLEAR;
                    elsif(counter = DISPLAY_CLEAR_TIME) then
                        current_lcd_state <= ENTRY_MODE_SET;
                        counter := 0;
                    else
                        current_lcd_state <= DISPLAY_CLEAR;
                        init_mode_enable <= '0';
                    end if;
                    counter := counter + 1;
                when ENTRY_MODE_SET =>
                    init_mode_data <= X"06";
                    init_mode_rs <= '0';
                    init_mode_rw <= '0';
                    if(counter = 0) then 
                        init_mode_enable <= '1';
                        current_lcd_state <= ENTRY_MODE_SET;
                    elsif(counter = PULSE_WDITH) then
                        current_lcd_state <= RUN_MODE;
                        counter := 0;
                    else
                        current_lcd_state <= ENTRY_MODE_SET;
                        init_mode_enable <= '0';
                    end if;
                    counter := counter + 1;
                when others =>
                    current_lcd_state <= RUN_MODE;
            end case;
        end if;
     end process main_statemachine_proc;

-- ============================================================================
-- Process Name: enable_pulse_proc
-- Description : This process generates a pulse signal on the `ENABLE` output
--               based on the `enable_out` signal and the `LCD_CLK` clock.
--               The pulse width is determined by the constant `PULSE_WDITH`.
-- 
-- Inputs      : 
--   - LCD_CLK   : Clock signal used to synchronize the process.
--   - enable_out: Signal that triggers the start of the pulse generation.
-- 
-- Outputs     : 
--   - ENABLE    : Output signal that generates a pulse of width `PULSE_WDITH`.
-- 
-- Internal Variables:
--   - counter_en: Boolean variable used to enable or disable the counter.
--   - counter   : Integer variable used to count clock cycles for the pulse.
-- 
-- Behavior    :
--   1. When `enable_out` is high, the counter is reset to 0 and the counter
--      is enabled (`counter_en` is set to true).
--   2. On the rising edge of `LCD_CLK`, if the counter is enabled:
--      - The counter increments by 1.
--      - If the counter value is less than `PULSE_WDITH`, the `ENABLE` signal
--        is set to '1'.
--      - Otherwise, the `ENABLE` signal is set to '0' and the counter is
--        disabled (`counter_en` is set to false).
-- ============================================================================
     enable_pulse_proc: process(LCD_CLK, enable_out) is
        variable counter_en: boolean := false;
        variable counter: integer := 0;
     begin
        if(enable_out = '1') then
            counter := 0;
            counter_en := true;
        elsif(rising_edge(LCD_CLK)) then
            if(counter_en = true) then
                counter := counter + 1;
                if(counter < PULSE_WDITH) then
                   ENABLE <= '1';
                else
                   ENABLE <= '0';
                   counter_en := false;
                end if;
            end if;
        end if;
     end process enable_pulse_proc;
end synth_logic;
