library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_audio_sink is
    generic (
        d_width : integer := 24
    );
    port (
        -- 125 MHz Board-Takt
        clock            : in  std_logic;

        -- exportierter Audiotakt für weitere PL-Logik / FIFO
        audio_clk_out    : out std_logic;
        audio_resetn_out : out std_logic;

        -- AXI4-Stream Eingang (64 Bit Stereo-Frames)
        s_axis_tdata     : in  std_logic_vector(63 downto 0);
        s_axis_tvalid    : in  std_logic;
        s_axis_tready    : out std_logic;

        -- I2S nach außen
        mclk             : out std_logic_vector(1 downto 0);
        sclk             : out std_logic_vector(1 downto 0);
        ws               : out std_logic_vector(1 downto 0);
        sd_rx            : in  std_logic;
        sd_tx            : out std_logic;

        -- Debug
        underrun         : out std_logic
    );
end entity;

architecture rtl of i2s_audio_sink is

    signal master_clk   : std_logic;
    signal pll_locked   : std_logic;

    signal serial_clk   : std_logic := '0';
    signal word_select  : std_logic := '0';

    signal l_data_rx    : std_logic_vector(d_width-1 downto 0);
    signal r_data_rx    : std_logic_vector(d_width-1 downto 0);
    signal l_data_tx    : std_logic_vector(d_width-1 downto 0);
    signal r_data_tx    : std_logic_vector(d_width-1 downto 0);

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

    -- Audiotakt nach außen geben
    audio_clk_out    <= master_clk;
    audio_resetn_out <= pll_locked;

    -- Stream-Consumer: nimmt 64-Bit-Stereo-Frames an
    stream_consumer_inst : entity work.audio_stream_consumer
        generic map (
            d_width => d_width
        )
        port map (
            clk           => master_clk,
            reset_n       => pll_locked,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            ws            => word_select,
            l_data_tx     => l_data_tx,
            r_data_tx     => r_data_tx,
            underrun      => underrun
        );

    -- I2S-Transceiver
    i2s_transceiver_0 : entity work.i2s_transceiver
        generic map (
            mclk_sclk_ratio => 4,
            sclk_ws_ratio   => 64,
            d_width         => d_width
        )
        port map (
            reset_n   => pll_locked,
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

    -- gleiche Takte für ADC und DAC
    mclk <= (others => master_clk);
    sclk <= (others => serial_clk);
    ws   <= (others => word_select);

end architecture;