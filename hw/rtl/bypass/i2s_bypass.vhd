library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_bypass is
    generic (
        d_width : integer := 24
    );
    port (
        clock : in  std_logic;                           -- 125 MHz board clock
        mclk  : out std_logic_vector(1 downto 0);       -- MCLK to ADC and DAC side
        sclk  : out std_logic_vector(1 downto 0);       -- BCLK to ADC and DAC side
        ws    : out std_logic_vector(1 downto 0);       -- LRCK / WS to ADC and DAC side
        sd_rx : in  std_logic;                          -- serial data from ADC side
        sd_tx : out std_logic                           -- serial data to DAC side
    );
end entity;

architecture rtl of i2s_bypass is

    signal master_clk   : std_logic;
    signal pll_locked   : std_logic;
    signal serial_clk   : std_logic := '0';
    signal word_select  : std_logic := '0';
    signal sample_tick  : std_logic := '0';

    signal l_data_rx    : std_logic_vector(d_width-1 downto 0);
    signal r_data_rx    : std_logic_vector(d_width-1 downto 0);
    signal l_data_tx    : std_logic_vector(d_width-1 downto 0) := (others => '0');
    signal r_data_tx    : std_logic_vector(d_width-1 downto 0) := (others => '0');

    component clk_wiz_0
        port (
            clk_in1  : in  std_logic;
            clk_out1 : out std_logic;
            reset    : in  std_logic;
            locked   : out std_logic
        );
    end component;

begin

    -- Clock Wizard: 125 MHz -> 12.288 MHz
    i2s_clock : clk_wiz_0
        port map (
            clk_in1  => clock,
            clk_out1 => master_clk,
            reset    => '0',
            locked   => pll_locked
        );

    -- I2S transceiver in master mode.
    -- The FPGA generates MCLK/SCLK/WS for both the ADC and DAC side of the Pmod I2S2.
    i2s_transceiver_0 : entity work.i2s_transceiver
        generic map (
            mclk_sclk_ratio => 4,
            sclk_ws_ratio   => 64,
            d_width         => d_width
        )
        port map (
            reset_n     => pll_locked,
            mclk        => master_clk,
            sclk        => serial_clk,
            ws          => word_select,
            sample_tick => sample_tick,
            sd_tx       => sd_tx,
            sd_rx       => sd_rx,
            l_data_tx   => l_data_tx,
            r_data_tx   => r_data_tx,
            l_data_rx   => l_data_rx,
            r_data_rx   => r_data_rx
        );

    -- Simple stereo-frame bypass.
    --
    -- Future DSP stages can replace the two assignments inside sample_tick with
    -- their own processing chain, for example:
    --   * gain / mute
    --   * FIR / IIR filters
    --   * delay / echo
    --   * FFT-based processing
    --
    -- sample_tick pulses once per complete stereo frame. On that pulse,
    -- l_data_rx/r_data_rx are stable and contain the newest received samples.
    -- The values written to l_data_tx/r_data_tx will be transmitted in the
    -- following stereo frame.
    process(master_clk)
    begin
        if rising_edge(master_clk) then
            if pll_locked = '0' then
                l_data_tx <= (others => '0');
                r_data_tx <= (others => '0');
            else
                if sample_tick = '1' then
                    l_data_tx <= l_data_rx;
                    r_data_tx <= r_data_rx;
                end if;
            end if;
        end if;
    end process;

    -- Same clocks to both Pmod I2S2 rows.
    mclk <= (others => master_clk);
    sclk <= (others => serial_clk);
    ws   <= (others => word_select);

end architecture;
