library ieee;
use ieee.std_logic_1164.all;

use work.std_logic_vector_arrays.all;

entity lcd_controller_tb is
end lcd_controller_tb;

architecture Behavioral of lcd_controller_tb is
    procedure clock_generator(signal CLK : out std_logic; 
                              constant FREQ : real; 
                              PHASE : time := 0 fs; 
                              signal RUN : std_logic) is
        constant HIGH_TIME   : time := 0.5 sec / FREQ;
        variable low_time_v  : time;
        variable cycles_v    : real := 0.0;
        variable freq_time_v : time := 0 fs;
    begin
        assert (HIGH_TIME /= 0 fs) report "clk_gen: High time is zero; time resolution to large for frequency" severity FAILURE;
        clk <= '0';
        wait for PHASE;
        loop
            if (run = '1') or (run = 'H') then
                clk <= run;
            end if;
            wait for HIGH_TIME;
            clk <= '0';
            low_time_v := 1 sec * ((cycles_v + 1.0) / FREQ) - freq_time_v - HIGH_TIME; 
            wait for low_time_v;
            cycles_v := cycles_v + 1.0;
            freq_time_v := freq_time_v + HIGH_TIME + low_time_v;
        end loop;
    end procedure;

    signal clk_en: std_logic := '0';
    signal LCD_CLK: std_logic := '0';
    signal RESETN: std_logic := '0';
    signal ENABLE: std_logic := '0';
    signal LCD_LINES: std_logic_vector(9 downto 0) := (others => '0');
    signal LINE_ONE: slv_array(0 to 15)(7 downto 0) := (others => (others => '0'));
    signal LINE_TWO: slv_array(0 to 15)(7 downto 0) := (others => (others => '0'));
begin
    clock_generator(CLK => LCD_CLK, FREQ => 100.0E6, RUN => clk_en);
    UUT: entity work.lcd_controller port map(LCD_CLK => LCD_CLK,
                                             RESETN => RESETN,
                                             ENABLE => ENABLE,
                                             LCD_LINES => LCD_LINES,
                                             LINE_ONE => LINE_ONE,
                                             LINE_TWO => LINE_TWO);
    clk_en <= '1' after 10 ns;
    RESETN <= '1' after 1 us;
end Behavioral;
