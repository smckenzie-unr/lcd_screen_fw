library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;

entity axi4_lite_slave_if is
    generic(AXI_DATA_BUS_WIDTH      : integer range 32 to 128 := 32;
            AXI_ADDRESS_BUS_WIDTH   : integer range 32 to 128 := 32;
            NUMBER_OF_REGISTERS     : integer range 1 to 1024 := 4);
    port(S_AXI_CLK                  : in std_logic;
         S_AXI_ARESETN              : in std_logic; 
         S_AXI_ARVALID              : in std_logic;
         S_AXI_ARREADY              : out std_logic;
         S_AXI_ARADDR               : in std_logic_vector(AXI_ADDRESS_BUS_WIDTH - 1 downto 0);
         S_AXI_RVALID               : out std_logic;
         S_AXI_RREADY               : in std_logic;
         S_AXI_RDATA                : out std_logic_vector(AXI_DATA_BUS_WIDTH - 1 downto 0);
         S_AXI_RRESP                : out std_logic_vector(1 downto 0);
         S_AXI_ARPROT               : in std_logic_vector(2 downto 0);
         S_AXI_AWVALID              : in std_logic;
         S_AXI_AWREADY              : out std_logic;
         S_AXI_AWADDR               : in std_logic_vector(AXI_ADDRESS_BUS_WIDTH - 1 downto 0);
         S_AXI_AWPROT               : in std_logic_vector(2 downto 0);
         S_AXI_WVALID               : in std_logic;
         S_AXI_WREADY               : out std_logic;
         S_AXI_WDATA                : in std_logic_vector(AXI_DATA_BUS_WIDTH - 1 downto 0);
         S_AXI_WSTRB                : in std_logic_vector((AXI_DATA_BUS_WIDTH / 8) - 1 downto 0);
         S_AXI_BVALID               : out std_logic;
         S_AXI_BREADY               : in std_logic;
         S_AXI_BRESP                : out std_logic_vector(1 downto 0));
end axi4_lite_slave_if;

architecture synth_logic of axi4_lite_slave_if is
    type read_statemachine is (IDLE, ADDRESS_LATCH, DATA_OUT, ADDRESS_ERROR);
    type write_statemachine is (IDLE, ADDRESS_LATCH, DATA_IN, RESPONSE_OUT, ADDRESS_ERROR);
    type register_array is array (0 to NUMBER_OF_REGISTERS - 1) of std_logic_vector(AXI_DATA_BUS_WIDTH - 1 downto 0);
    constant ADDR_LSB       : integer := (AXI_ADDRESS_BUS_WIDTH / 32) + 1;
    constant ADDR_MSB       : integer := integer(ceil(log2(real(NUMBER_OF_REGISTERS - 1)))) + ADDR_LSB - 1;
    constant OKAY           : std_logic_vector(1 downto 0) := "00";
    constant EXOKAY         : std_logic_vector(1 downto 0) := "01";
    constant SLVERR         : std_logic_vector(1 downto 0) := "10";
    constant DECERR         : std_logic_vector(1 downto 0) := "11";
    signal slv_registers    : register_array := (others => (others => '0'));
    signal read_address     : integer := 0;
    signal write_address    : integer := 0;
    signal axi_arready      : std_logic := '0';
    signal axi_rvalid       : std_logic := '0';
    signal axi_rdata        : std_logic_vector(AXI_DATA_BUS_WIDTH - 1 downto 0) := (others => '0');
    signal axi_rresp        : std_logic_vector(1 downto 0) := SLVERR;
    signal axi_awready      : std_logic := '0';
    signal axi_wready       : std_logic := '0';
    signal axi_bvalid       : std_logic := '0';
    signal axi_bresp        : std_logic_vector(1 downto 0) := SLVERR;
begin
    S_AXI_ARREADY <= axi_arready;
    S_AXI_RVALID <= axi_rvalid;
    S_AXI_RDATA <= axi_rdata;
    S_AXI_RRESP <= axi_rresp;
    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY <= axi_wready;
    S_AXI_BVALID <= axi_bvalid;
    S_AXI_BRESP <= axi_bresp;
    read_statemachine_proc : process(S_AXI_CLK) is
        variable current_read_state : read_statemachine := IDLE;
    begin
        if(rising_edge(S_AXI_CLK)) then
            if(S_AXI_ARESETN = '0') then
                axi_arready <= '0';
                axi_rvalid <= '0';
                axi_rdata <= (others => '0');
                axi_rresp <= SLVERR;
            else
                case current_read_state is
                    when DATA_OUT =>
                        axi_arready <= '0';
                        axi_rvalid <= '1';
                        axi_rdata <= slv_registers(read_address);
                        axi_rresp <= OKAY;
                        if(S_AXI_RREADY = '1') then
                            current_read_state := IDLE;
                        else
                            current_read_state := DATA_OUT;
                        end if;
                    when ADDRESS_ERROR =>
                        axi_arready <= '0';
                        axi_rvalid <= '1';
                        axi_rresp <= DECERR;
                        if(S_AXI_RREADY = '1') then
                            current_read_state := IDLE;
                        else
                            current_read_state := ADDRESS_ERROR;
                        end if;
                    when ADDRESS_LATCH =>
                        axi_arready <= '1';
                        read_address <= to_integer(unsigned(S_AXI_ARADDR(ADDR_MSB downto ADDR_LSB)));
                        if(read_address < NUMBER_OF_REGISTERS) then
                            current_read_state := DATA_OUT;
                        else
                            current_read_state := ADDRESS_ERROR;
                        end if;
                    when others => --IDLE
                        axi_rvalid <= '0';
                        axi_rresp <= SLVERR;
                        if(S_AXI_ARVALID = '1') then
                            current_read_state := ADDRESS_LATCH;
                        else
                            current_read_state := IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process read_statemachine_proc;
    write_statemachine_proc : process(S_AXI_CLK) is
        variable current_write_state : write_statemachine := IDLE;
    begin
        if(rising_edge(S_AXI_CLK)) then
            if(S_AXI_ARESETN = '0') then
                current_write_state := IDLE;
                axi_awready <= '0';
                axi_wready <= '0';
                axi_bvalid <= '0';
                axi_bresp <= SLVERR;
            else
                case current_write_state is
                    when DATA_IN =>
                        axi_awready <= '0';
                        axi_wready <= '1';
                        if(S_AXI_WVALID = '1') then
                            for byte_index in 0 to ((AXI_DATA_BUS_WIDTH / 8) - 1) loop
	                           if(S_AXI_WSTRB(byte_index) = '1') then
	                               slv_registers(write_address)(byte_index * 8 + 7 downto byte_index * 8) <= S_AXI_WDATA(byte_index * 8 + 7 downto byte_index * 8);
	                           end if;
	                        end loop;
	                        current_write_state := RESPONSE_OUT;
                        else
                            current_write_state := DATA_IN;
                        end if;                        
                    when RESPONSE_OUT =>
                        axi_wready <= '0';
                        axi_bvalid <= '1';
                        axi_bresp <= OKAY;
                        if(S_AXI_BREADY = '1') then
                            current_write_state := IDLE;
                        else
                            current_write_state := RESPONSE_OUT;
                        end if;
                    when ADDRESS_ERROR =>
                        axi_awready <= '0';
                        axi_bvalid <= '1';
                        axi_bresp <= DECERR;
                        if(S_AXI_BREADY = '1') then
                            current_write_state := IDLE;
                        else
                            current_write_state := ADDRESS_ERROR;
                        end if;
                    when ADDRESS_LATCH =>
                        axi_awready <= '1';
                        write_address <= to_integer(unsigned(S_AXI_AWADDR(ADDR_MSB downto ADDR_LSB)));
                        if(write_address < NUMBER_OF_REGISTERS) then
                            current_write_state := DATA_IN;
                        else
                            current_write_state := ADDRESS_ERROR;
                        end if;
                    when others => --IDLE
                        axi_bvalid <= '0';
                        axi_bresp <= SLVERR;
                        if(S_AXI_AWVALID = '1') then
                            current_write_state := ADDRESS_LATCH;
                        else
                            current_write_state := IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process write_statemachine_proc;
end synth_logic;
