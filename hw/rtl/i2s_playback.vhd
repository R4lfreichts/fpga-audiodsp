library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_playback is
    generic (
        d_width : integer := 24
    );
    port (
        clock : in  std_logic;                           -- 125 MHz
        btn_l : in  std_logic;                           -- previous note
        btn_r : in  std_logic;                           -- next note
        mclk  : out std_logic_vector(1 downto 0);       -- MCLK ADC/DAC
        sclk  : out std_logic_vector(1 downto 0);       -- BCLK
        ws    : out std_logic_vector(1 downto 0);       -- LRCK
        sd_rx : in  std_logic;                          -- ADC data, unused
        sd_tx : out std_logic                           -- DAC data
    );
end i2s_playback;

architecture rtl of i2s_playback is

    component clk_wiz_0
        port (
            clk_in1  : in  std_logic;
            clk_out1 : out std_logic;
            reset    : in  std_logic;
            locked   : out std_logic
        );
    end component;

    signal master_clk   : std_logic;
    signal pll_locked   : std_logic;
    signal serial_clk   : std_logic := '0';
    signal word_select  : std_logic := '0';
    signal sample_tick  : std_logic := '0';

    signal l_data_rx    : std_logic_vector(d_width-1 downto 0);
    signal r_data_rx    : std_logic_vector(d_width-1 downto 0);
    signal l_data_tx    : std_logic_vector(d_width-1 downto 0) := (others => '0');
    signal r_data_tx    : std_logic_vector(d_width-1 downto 0) := (others => '0');

    signal btn_l_pulse  : std_logic;
    signal btn_r_pulse  : std_logic;

    constant PHASE_BITS : integer := 32;
    constant N_NOTES    : integer := 8;

    signal phase_acc    : unsigned(PHASE_BITS-1 downto 0) := (others => '0');
    signal note_index   : integer range 0 to N_NOTES-1 := 0;

    -- C major scale with A4 = 440 Hz:
    -- C4, D4, E4, F4, G4, A4, B4, C5
    -- phase_inc = round(f_note * 2^32 / 44100)
    type note_inc_t is array (0 to N_NOTES-1) of unsigned(PHASE_BITS-1 downto 0);
    constant NOTE_INC : note_inc_t := (
        0 => to_unsigned(25480119, PHASE_BITS), -- C4 = 261.63 Hz
        1 => to_unsigned(28600467, PHASE_BITS), -- D4 = 293.66 Hz
        2 => to_unsigned(32102938, PHASE_BITS), -- E4 = 329.63 Hz
        3 => to_unsigned(34011878, PHASE_BITS), -- F4 = 349.23 Hz
        4 => to_unsigned(38177043, PHASE_BITS), -- G4 = 392.00 Hz
        5 => to_unsigned(42852281, PHASE_BITS), -- A4 = 440.00 Hz
        6 => to_unsigned(48100060, PHASE_BITS), -- B4 = 493.88 Hz
        7 => to_unsigned(50960238, PHASE_BITS)  -- C5 = 523.25 Hz
    );

    type sine_qtr_t is array (0 to 63) of std_logic_vector(23 downto 0);
    constant SINE_QTR : sine_qtr_t := (
        0  => x"000000",
        1  => x"019877",
        2  => x"0330AD",
        3  => x"04C861",
        4  => x"065F52",
        5  => x"07F53F",
        6  => x"0989E8",
        7  => x"0B1D0D",
        8  => x"0CAE6D",
        9  => x"0E3DC8",
        10 => x"0FCADF",
        11 => x"115573",
        12 => x"12DD45",
        13 => x"146216",
        14 => x"15E3A8",
        15 => x"1761BF",
        16 => x"18DC1D",
        17 => x"1A5287",
        18 => x"1BC4C0",
        19 => x"1D328E",
        20 => x"1E9BB6",
        21 => x"200000",
        22 => x"215F31",
        23 => x"22B913",
        24 => x"240D6F",
        25 => x"255C0E",
        26 => x"26A4BB",
        27 => x"27E741",
        28 => x"29236E",
        29 => x"2A590F",
        30 => x"2B87F3",
        31 => x"2CAFE9",
        32 => x"2DD0C2",
        33 => x"2EEA52",
        34 => x"2FFC6A",
        35 => x"3106DF",
        36 => x"320986",
        37 => x"330437",
        38 => x"33F6CA",
        39 => x"34E118",
        40 => x"35C2FB",
        41 => x"369C51",
        42 => x"376CF5",
        43 => x"3834C7",
        44 => x"38F3A8",
        45 => x"39A978",
        46 => x"3A561C",
        47 => x"3AF976",
        48 => x"3B936F",
        49 => x"3C23EC",
        50 => x"3CAAD7",
        51 => x"3D281A",
        52 => x"3D9BA2",
        53 => x"3E055C",
        54 => x"3E6537",
        55 => x"3EBB24",
        56 => x"3F0716",
        57 => x"3F4900",
        58 => x"3F80D8",
        59 => x"3FAE95",
        60 => x"3FD22F",
        61 => x"3FEBA1",
        62 => x"3FFAE7",
        63 => x"3FFFFF"
    );

    function sine_lookup(phase : unsigned(PHASE_BITS-1 downto 0)) return signed is
        variable quadrant : unsigned(1 downto 0);
        variable idx      : integer range 0 to 63;
        variable mag      : signed(23 downto 0);
    begin
        quadrant := phase(PHASE_BITS-1 downto PHASE_BITS-2);
        idx      := to_integer(phase(PHASE_BITS-3 downto PHASE_BITS-8));

        case quadrant is
            when "00" =>
                mag := signed(SINE_QTR(idx));
            when "01" =>
                mag := signed(SINE_QTR(63 - idx));
            when "10" =>
                mag := -signed(SINE_QTR(idx));
            when others =>
                mag := -signed(SINE_QTR(63 - idx));
        end case;

        return mag;
    end function;

begin

    i2s_clock : clk_wiz_0
        port map (
            clk_in1  => clock,
            clk_out1 => master_clk,
            reset    => '0',
            locked   => pll_locked
        );

    btn_left_inst : entity work.button_onepulse
        generic map (
            debounce_len => 250000
        )
        port map (
            clk    => master_clk,
            rst_n  => pll_locked,
            btn_in => btn_l,
            pulse  => btn_l_pulse
        );

    btn_right_inst : entity work.button_onepulse
        generic map (
            debounce_len => 250000
        )
        port map (
            clk    => master_clk,
            rst_n  => pll_locked,
            btn_in => btn_r,
            pulse  => btn_r_pulse
        );

    i2s_transceiver_0 : entity work.i2s_transceiver
        generic map (
            mclk_sclk_ratio => 4,
            sclk_ws_ratio   => 64,
            d_width         => 24
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

    process(master_clk)
        variable phase_next  : unsigned(PHASE_BITS-1 downto 0);
        variable sample_next : signed(d_width-1 downto 0);
    begin
        if rising_edge(master_clk) then
            if pll_locked = '0' then
                note_index <= 0;
                phase_acc  <= (others => '0');
                l_data_tx  <= (others => '0');
                r_data_tx  <= (others => '0');
            else
                if (btn_r_pulse = '1') and (note_index > 0) then
                    note_index <= note_index - 1;
                elsif (btn_l_pulse = '1') and (note_index < N_NOTES - 1) then
                    note_index <= note_index + 1;
                end if;

                if sample_tick = '1' then
                    phase_next  := phase_acc + NOTE_INC(note_index);
                    phase_acc   <= phase_next;
                    sample_next := resize(sine_lookup(phase_next), d_width);

                    l_data_tx <= std_logic_vector(sample_next);
                    r_data_tx <= std_logic_vector(sample_next);
                end if;
            end if;
        end if;
    end process;

    mclk <= (others => master_clk);
    sclk <= (others => serial_clk);
    ws   <= (others => word_select);

end rtl;