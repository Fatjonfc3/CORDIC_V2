use IEEE.numeric_std.all;

use IEEE.numeric_std.all;


entity cordic 
port (
	x_in : in std_logic_vector (15 downto 0 ) ; -- arbitrary , technically we suppose some adc input so fixed point
	y_in : in std_logic_vector ( 15 downto 0 );
	angle_req : in std_logic_vector (31 downto 0 ) ; -- it depends on the resolution we want  
	freq : in std_logic_vector ( 31 downto 0) ; -- angle has the same as freq , because in each step the signal generated will have a phase of 2pift = in discrete world 2pi f0/fs * n
	clk , rst : in std_logic ;
	x_out ,y_out : out std_logic_vector ( 21 downto 0 ) --wider because to have a higher resolution we add some bits, basically since we will be working in fixed point world because a lot of right shifts ( divisions will be done) to not lose a lot of accuracy we add some bits
	
)
end entity cordic ; -- add parameters to make it more customizable

architecture rtl of cordic is
--===========SAMPLED INPUT=====
signal x_in_reg , y_in_reg : signed ( 21 downto 0 ); -- 
signal x_pre_rotated , y_pre_rotated : signed ( 21 downto 0); -- since CORDIC converges only in 90 degrees (or 45 to be more strict to the algorithm as a monotonic algorithm)
signal x_in_neg , y_in_neg : signed (21 downto 0 ); -- just as a fast solution in the comb circuit as soon as we get the sampled input
--=========PHASE STEP  for a modulator example and phase accumulator
signal phase_step : unsigned ( 31 downto 0 ) ; -- fo/fs ratio, positive so no need for unsigned= angle lets say we precompute it
signal phase_acc : unsigned ( 31 downto 0 ) ; -- the max is 360
--=========NUMBER OF ITERATION -> max nr of iteration the width of the input otherwise we would just go to 0 bcs if we right shift a 22 bit number with 22
constant  iteration_number : integer := 22 ; -- create a subtype that limits this integer
--======TYPES NEEDED FOR THE CORDIC PIPELINE , x , y and the angle
type cordic_array is array of signed (0 to 21) of signed ( 21 downto 0 );
type angle_array is array of signed ( 0 to 21) of signed ( 31 downto 0 );

signal x_cordic , y_cordic : cordic_array ;
signal angle_cordic : angle_array;
--=====


begin


SAMPLE_INPUT:process ( clk )
begin
 if rising_edge ( clk ) then
		x_in_reg <= signed(x_in & ( (5 downto 0) => '0')); --just added 6 bits for accuracy , everything stored as it was basically we multiplied by 2**6 so a fractional part of 6 bits
		y_in_reg <= signed(y_in & ( (5 downto 0 ) => '0'));
		phase_step <= signed(angle_req);
end if;
end process SAMPLE_INPUT;
-- pipelined manner
ACC_PHASE : process ( clk ) 
begin
	if rising_edge ( clk ) then
		phase_acc <= phase_acc + phase_step ; --since its a pipelien it's okay

end ACC_PHASE;

x_in_neg <= -x_in_reg; -- supported by numeric_std.all , just invert 2s complement input so invert it + 1, just used to not waste time on calculating it later for the pipeline
y_in_neg <= -y_in_reg;
--======PRE ROTATION STAGE
ROTATE : process ( clk )
begin
	if rising_edge ( clk ) then
		case ( phase_acc ( 31 downto 30 )) is
			when "00" =>
			when "11" =>
				x_cordic(0) <= x_in_reg;
				y_cordic (0) <= y_in_reg;
				angle_cordic ( 0 ) <= phase_acc;
			when "01" => -- we shift the signal with 90 degrees , positive 90 degrees
				x_cordic(0) <= y_in_neg
				y_cordic (0) <= x_in_reg;
				angle_cordic (0) <= "00" & phase_acc (29 downto 0 );
			when "10" => -- we shift the signal with -90 degrees since the angle is higher that 180
				x_cordic (0) <= y_in_reg;
				y_cordic (0) <= x_in_neg;
				angle_cordic(0) <= "11" & phase_acc (29 downto 0 );
		end case;
	end if;
end process ROTATE;
				
				
--=====FIRST STAGE
FIRST_STAGE: process ( clk )
begin
	if rising_edge ( clk ) then
		if angle_cordic (0) > 0 then
			x_cordic ( 1 ) <= x_cordic ( 0 ) - (y_cordic(0) srl 1);
			y_cordic ( 1 ) <= y_cordic ( 0 ) + ( x_cordic(0) srl 1 );
			angle_cordic ( 1) <= angle_cordic ( 0 ) - angle_lut ( 0 )
		else
			x_cordic ( 1 ) <= x_cordic ( 0 ) + (y_cordic(0) srl 1);
			y_cordic ( 1 ) <= y_cordic ( 0 ) - ( x_cordic(0) srl 1 );
			angle_cordic ( 1) <= angle_cordic ( 0 ) + angle_lut ( 0 )
		end if;
end process FIRST_STAGE

--====NEXT STAGES , we exploit a for loop in hw just to be more readable anad not write 22 times
NEXT_STAGE : process ( clk)
begin
	if rising_edge ( clk ) then
		for I in 1 to 21 loop
			if angle_cordic ( I - 1 ) > 0 then
				x_cordic (I) <= x_cordic ( I - 1) - ( y_cordic (I -1 ) srl I ) ;
				y_cordic ( I ) <= y_cordic ( I - 1 ) + (x_cordic( I - 1) srl I );
				angle_cordic ( i) <= angle_cordic ( i-1 ) - angle_lut ( i-1 ) ;
			else
				x_cordic (I) <= x_cordic ( I - 1) + ( y_cordic (I -1 ) srl I ) ;
				y_cordic ( I ) <= y_cordic ( I - 1 ) - (x_cordic( I - 1) srl I );
				angle_cordic ( i) <= angle_cordic ( i-1 ) + angle_lut ( i-1 );
			end if; 
			
		end loop;
	end if;

end process NEXT_STAGE;

x_out <= std_logic_vector (x_cordic ( 21 ));
y_out <= std_logic_vector ( y_cordic ( 21 ) );

end architecture rtl;
