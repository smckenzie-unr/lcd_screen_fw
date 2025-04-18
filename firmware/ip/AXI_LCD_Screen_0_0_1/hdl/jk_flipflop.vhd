library ieee;
use ieee.std_logic_1164.all;

-- Include the Xilinx unisim library for FDRE
library unisim;
use unisim.vcomponents.all;

entity JK_FF is
    port(J: in  std_logic;      -- J input
         K: in  std_logic;      -- K input
         CLOCK: in  std_logic;  -- Clock input
         Q: out std_logic);     -- Q output
end JK_FF;

architecture synth_logic of JK_FF is
    signal D : std_logic;           -- D input for the FDRE
    signal Q_internal : std_logic;  -- Internal signal for Q
begin
    -- Derive D input logic from J, K, and Q_internal
    D <= (J and not Q_internal) or (not K and Q_internal);

    -- Instantiate Xilinx FDRE primitive
    FDRE_inst: FDRE generic map (INIT => '0')   -- Initial value of Q
                    port map (C => CLOCK,       -- Clock input
                              CE => '1',          -- Clock enable (always enabled)
                              D => D,             -- D input
                              Q => Q_internal,    -- Q output
                              R => '0');          -- Reset (not used here)
    -- Assign outputs
    Q <= Q_internal;
end synth_logic;