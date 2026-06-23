library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity audio_fx_top is
    generic (
        d_width : integer := 24
    );
    port (
        clock    : in  std_logic;                          -- 125 MHz board clock
        btn_up   : in  std_logic;                          -- gain increase
        btn_down : in  std_logic;                          -- gain decrease

        mclk     : out std_logic_vector(1 downto 0);      -- MCLK to ADC and DAC side
        sclk     : out std_logic_vector(1 downto 0);      -- BCLK to ADC and DAC side
        ws       : out std_logic_vector(1 downto 0);      -- LRCK / WS to ADC and DAC side
        sd_rx    : in  std_logic;                         -- serial data from ADC side
        sd_tx    : out std_logic                          -- serial data to DAC side
    );
end entity audio_fx_top;

architecture rtl of audio_fx_top is

    constant gain_min : integer := -3;
    constant gain_max : integer :=  3;

    signal master_clk    : std_logic;
    signal pll_locked    : std_logic;
    signal serial_clk    : std_logic := '0';
    signal word_select   : std_logic := '0';
    signal sample_tick   : std_logic := '0';

    -- Button handling
    signal btn_up_pulse   : std_logic := '0';
    signal btn_down_pulse : std_logic := '0';
    signal gain_shift_reg : integer range gain_min to gain_max := 0;

    -- Sample stream from I2S receiver
    signal l_sample_rx   : std_logic_vector(d_width-1 downto 0);
    signal r_sample_rx   : std_logic_vector(d_width-1 downto 0);

    -- Sample stream after gain stage
    signal l_sample_fx0  : std_logic_vector(d_width-1 downto 0) := (others => '0');
    signal r_sample_fx0  : std_logic_vector(d_width-1 downto 0) := (others => '0');

	-- Sample stream after clipping stage
	signal l_sample_fx1 : std_logic_vector(d_width-1 downto 0) := (others => '0');
	signal r_sample_fx1 : std_logic_vector(d_width-1 downto 0) := (others => '0');

    -- Sample stream to I2S transmitter
    signal l_sample_tx   : std_logic_vector(d_width-1 downto 0) := (others => '0');
    signal r_sample_tx   : std_logic_vector(d_width-1 downto 0) := (others => '0');

    component clk_wiz_0
        port (
            clk_in1  : in  std_logic;
            clk_out1 : out std_logic;
            reset    : in  std_logic;
            locked   : out std_logic
        );
    end component;

begin

    ---------------------------------------------------------------------------
    -- Clock generation
    ---------------------------------------------------------------------------
    i2s_clock : clk_wiz_0
        port map (
            clk_in1  => clock,
            clk_out1 => master_clk,
            reset    => '0',
            locked   => pll_locked
        );

    ---------------------------------------------------------------------------
    -- I2S transceiver
    ---------------------------------------------------------------------------
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
            l_data_tx   => l_sample_tx,
            r_data_tx   => r_sample_tx,
            l_data_rx   => l_sample_rx,
            r_data_rx   => r_sample_rx
        );

    ---------------------------------------------------------------------------
    -- Button one-pulse generation
    ---------------------------------------------------------------------------
    btn_up_inst : entity work.button_onepulse
        generic map (
            debounce_len => 250000
        )
        port map (
            clk    => master_clk,
            rst_n  => pll_locked,
            btn_in => btn_up,
            pulse  => btn_up_pulse
        );

    btn_down_inst : entity work.button_onepulse
        generic map (
            debounce_len => 250000
        )
        port map (
            clk    => master_clk,
            rst_n  => pll_locked,
            btn_in => btn_down,
            pulse  => btn_down_pulse
        );

    ---------------------------------------------------------------------------
    -- Gain control register
    --
    -- btn_up   -> gain + 1
    -- btn_down -> gain - 1
    --
    -- range:
    --   -3, -2, -1, 0, +1, +2, +3
    ---------------------------------------------------------------------------
    process(master_clk)
    begin
        if rising_edge(master_clk) then
            if pll_locked = '0' then
                gain_shift_reg <= 0;
            else
                if (btn_up_pulse = '1') and (btn_down_pulse = '0') then
                    if gain_shift_reg < gain_max then
                        gain_shift_reg <= gain_shift_reg + 1;
                    end if;
                elsif (btn_down_pulse = '1') and (btn_up_pulse = '0') then
                    if gain_shift_reg > gain_min then
                        gain_shift_reg <= gain_shift_reg - 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Effect chain: RX -> fx_gain -> TX
    ---------------------------------------------------------------------------
    fx_gain_0 : entity work.fx_gain
        generic map (
            d_width => d_width
        )
        port map (
            clk         => master_clk,
            reset_n     => pll_locked,
            sample_tick => sample_tick,
            gain_shift  => gain_shift_reg,
            l_in        => l_sample_rx,
            r_in        => r_sample_rx,
            l_out       => l_sample_fx0,
            r_out       => r_sample_fx0
        );

    -- l_sample_tx <= l_sample_fx0;
    -- r_sample_tx <= r_sample_fx0;
	
	---------------------------------------------------------------------------
    -- Effect chain: RX -> fx_gain -> fx_clipping -> TX
    ---------------------------------------------------------------------------
	fx_soft_clipping_0 : entity work.fx_soft_clipping
		generic map (
			d_width    => d_width,
			clip_shift => 1
		)
		port map (
			clk         => master_clk,
			reset_n     => pll_locked,
			sample_tick => sample_tick,
			l_in        => l_sample_fx0,
			r_in        => r_sample_fx0,
			l_out       => l_sample_fx1,
			r_out       => r_sample_fx1
		);

	l_sample_tx <= l_sample_fx1;
	r_sample_tx <= r_sample_fx1;
	
	

    ---------------------------------------------------------------------------
    -- Same audio clocks to both Pmod I2S2 rows
    ---------------------------------------------------------------------------
    mclk <= (others => master_clk);
    sclk <= (others => serial_clk);
    ws   <= (others => word_select);

end architecture rtl;