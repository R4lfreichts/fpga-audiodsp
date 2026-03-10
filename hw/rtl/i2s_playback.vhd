library ieee;
use ieee.std_logic_1164.all;

entity i2s_playback is
    generic (
        d_width : integer := 24
    );
    port (
        clock : in  std_logic;                           -- 125 MHz
        mclk  : out std_logic_vector(1 downto 0);       -- MCLK ADC/DAC
        sclk  : out std_logic_vector(1 downto 0);       -- BCLK
        ws    : out std_logic_vector(1 downto 0);       -- LRCK
        sd_rx : in  std_logic;                          -- ADC-Daten, ungenutzt
        sd_tx : out std_logic                           -- DAC-Daten
    );
end i2s_playback;

architecture rtl of i2s_playback is

    signal master_clk  : std_logic;
    signal serial_clk  : std_logic := '0';
    signal word_select : std_logic := '0';

    signal l_data_rx   : std_logic_vector(d_width-1 downto 0);
    signal r_data_rx   : std_logic_vector(d_width-1 downto 0);
    signal l_data_tx   : std_logic_vector(d_width-1 downto 0) := (others => '0');
    signal r_data_tx   : std_logic_vector(d_width-1 downto 0) := (others => '0');

    constant N_SAMPLES : integer := 16;

    type sine_table_t is array (0 to N_SAMPLES-1) of std_logic_vector(23 downto 0);

    constant SINE_TABLE : sine_table_t := (
        0  => x"000000",
        1  => x"30FBC5",
        2  => x"5A8279",
        3  => x"7641AE",
        4  => x"7FFFFF",
        5  => x"7641AE",
        6  => x"5A8279",
        7  => x"30FBC5",
        8  => x"000000",
        9  => x"CF043B",
        10 => x"A57D87",
        11 => x"89BE52",
        12 => x"800001",
        13 => x"89BE52",
        14 => x"A57D87",
        15 => x"CF043B"
    );

    signal sample_index : integer range 0 to N_SAMPLES-1 := 0;
    signal ws_prev      : std_logic := '0';

begin

    -- PLL / Clock Wizard
    i2s_clock : entity work.clk_wiz_0
        port map (
            clk_in1  => clock,
            clk_out1 => master_clk,
            reset    => '0'
        );

    -- I2S-Block
    i2s_transceiver_0 : entity work.i2s_transceiver
        generic map (
            mclk_sclk_ratio => 4,
            sclk_ws_ratio   => 64,
            d_width         => 24
        )
        port map (
            reset_n   => '1',
            mclk      => master_clk,
            sclk      => serial_clk,
            ws        => word_select,
            sd_tx     => sd_tx,
            sd_rx     => sd_rx,
            l_data_tx => l_data_tx,
            r_data_tx => r_data_tx,
            l_data_rx => l_data_rx,
            r_data_rx => r_data_rx
        );

    -- nächstes Sample pro Stereo-Frame
    process (master_clk)
        variable idx_next : integer range 0 to N_SAMPLES-1;
    begin
        if rising_edge(master_clk) then
            if (ws_prev = '1') and (word_select = '0') then
                if sample_index = N_SAMPLES - 1 then
                    idx_next := 0;
                else
                    idx_next := sample_index + 1;
                end if;

                sample_index <= idx_next;
                l_data_tx    <= SINE_TABLE(idx_next);
                r_data_tx    <= SINE_TABLE(idx_next);
            end if;

            ws_prev <= word_select;
        end if;
    end process;

    -- gleiche Takte für ADC und DAC
    mclk <= (others => master_clk);
    sclk <= (others => serial_clk);
    ws   <= (others => word_select);

end rtl;