library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_playback is
    generic (
        d_width : integer := 24
    );
    port (
        clock : in  std_logic;                           -- 125 MHz Eingang
        btn_l : in  std_logic;                           -- Taste: Note runter
        btn_r : in  std_logic;                           -- Taste: Note hoch
        mclk  : out std_logic_vector(1 downto 0);       -- MCLK ADC/DAC
        sclk  : out std_logic_vector(1 downto 0);       -- BCLK
        ws    : out std_logic_vector(1 downto 0);       -- LRCK / WS
        sd_rx : in  std_logic;                          -- ADC-Daten, ungenutzt
        sd_tx : out std_logic                           -- DAC-Daten
    );
end i2s_playback;

architecture rtl of i2s_playback is

    signal master_clk  : std_logic;
    signal pll_locked  : std_logic;
    signal serial_clk  : std_logic := '0';
    signal word_select : std_logic := '0';

    signal l_data_rx   : std_logic_vector(d_width-1 downto 0);
    signal r_data_rx   : std_logic_vector(d_width-1 downto 0);
    signal l_data_tx   : std_logic_vector(d_width-1 downto 0) := (others => '0');
    signal r_data_tx   : std_logic_vector(d_width-1 downto 0) := (others => '0');

    signal btn_l_pulse : std_logic;
    signal btn_r_pulse : std_logic;

    signal ws_prev     : std_logic := '0';
    signal phase_acc   : unsigned(23 downto 0) := (others => '0');
    signal note_index  : integer range 0 to 7 := 0;

    constant N_SAMPLES : integer := 16;
    constant N_NOTES   : integer := 8;

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

    -- C3 D3 E3 F3 G3 A3 H3 C4
    -- phase_inc = round(f_note * 2^24 / 48000)
    type note_inc_t is array (0 to N_NOTES-1) of unsigned(23 downto 0);
    constant NOTE_INC : note_inc_t := (
        0 => x"00B299",  -- C3 = 130.81 Hz
        1 => x"00C879",  -- D3 = 146.83 Hz
        2 => x"00E105",  -- E3 = 164.81 Hz
        3 => x"00EE67",  -- F3 = 174.61 Hz
        4 => x"010B9B",  -- G3 = 196.00 Hz
        5 => x"012C60",  -- A3 = 220.00 Hz
        6 => x"015128",  -- H3 = 246.94 Hz
        7 => x"016536"   -- C4 = 261.63 Hz
    );

    component clk_wiz_0
        port (
            clk_in1  : in  std_logic;
            clk_out1 : out std_logic;
            reset    : in  std_logic;
            locked   : out std_logic
        );
    end component;

begin

    -- Clock Wizard
    i2s_clock : clk_wiz_0
        port map (
            clk_in1  => clock,
            clk_out1 => master_clk,
            reset    => '0',
            locked   => pll_locked
        );

    -- Entprellter Ein-Puls für linke Taste
    btn_left_inst : entity work.button_onepulse
        generic map (
            debounce_len => 250000
        )
        port map (
            clk    => master_clk,
            rst_n  => pll_locked,
            btn_in => btn_r,
            pulse  => btn_l_pulse
        );

    -- Entprellter Ein-Puls für rechte Taste
    btn_right_inst : entity work.button_onepulse
        generic map (
            debounce_len => 250000
        )
        port map (
            clk    => master_clk,
            rst_n  => pll_locked,
            btn_in => btn_l,
            pulse  => btn_r_pulse
        );

    -- I2S-Transceiver
    i2s_transceiver_0 : entity work.i2s_transceiver
        generic map (
            mclk_sclk_ratio => 4,
            sclk_ws_ratio   => 64,
            d_width         => 24
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

    -- Tastenauswertung + NCO + Sample-Update pro Stereo-Frame
    process(master_clk)
        variable phase_next : unsigned(23 downto 0);
        variable lut_index  : integer range 0 to N_SAMPLES-1;
    begin
        if rising_edge(master_clk) then
            if pll_locked = '0' then
                note_index <= 0;
                phase_acc  <= (others => '0');
                l_data_tx  <= (others => '0');
                r_data_tx  <= (others => '0');
                ws_prev    <= '0';
            else
                -- Note ändern
                if (btn_l_pulse = '1') and (note_index > 0) then
                    note_index <= note_index - 1;
                elsif (btn_r_pulse = '1') and (note_index < N_NOTES - 1) then
                    note_index <= note_index + 1;
                end if;

                -- Neues Sample pro Stereo-Frame
                if (ws_prev = '1') and (word_select = '0') then
                    phase_next := phase_acc + NOTE_INC(note_index);
                    phase_acc  <= phase_next;

                    -- Obere 4 Bit wählen 16er-Sinus-LUT
                    lut_index := to_integer(phase_next(23 downto 20));

                    l_data_tx <= SINE_TABLE(lut_index);
                    r_data_tx <= SINE_TABLE(lut_index);
                end if;

                ws_prev <= word_select;
            end if;
        end if;
    end process;

    -- Gleiche Takte für ADC und DAC
    mclk <= (others => master_clk);
    sclk <= (others => serial_clk);
    ws   <= (others => word_select);

end rtl;