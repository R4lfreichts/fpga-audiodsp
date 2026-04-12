library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity button_onepulse is
    generic (
        debounce_len : natural := 250000
    );
    port (
        clk    : in  std_logic;
        rst_n  : in  std_logic;
        btn_in : in  std_logic;
        pulse  : out std_logic
    );
end entity;

architecture rtl of button_onepulse is
    signal sync_0      : std_logic := '0';
    signal sync_1      : std_logic := '0';
    signal btn_state   : std_logic := '0';
    signal btn_state_d : std_logic := '0';
    signal cnt         : natural range 0 to debounce_len := 0;
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                sync_0      <= '0';
                sync_1      <= '0';
                btn_state   <= '0';
                btn_state_d <= '0';
                cnt         <= 0;
                pulse       <= '0';
            else
                sync_0 <= btn_in;
                sync_1 <= sync_0;

                pulse <= '0';
                btn_state_d <= btn_state;

                if sync_1 = btn_state then
                    cnt <= 0;
                else
                    if cnt = debounce_len then
                        btn_state <= sync_1;
                        cnt <= 0;
                    else
                        cnt <= cnt + 1;
                    end if;
                end if;

                if (btn_state = '1') and (btn_state_d = '0') then
                    pulse <= '1';
                end if;
            end if;
        end if;
    end process;

end architecture;