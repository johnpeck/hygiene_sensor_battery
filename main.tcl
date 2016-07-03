# Battery calculations for the Hygiene Sensor

source utils.tcl

# ----------------------------- Battery -------------------------------

# Rated battery capacity (mAh)
#
# This is the number you'll read off the package, or from a datasheet.
set rated_battery_capacity_mah 2850

# The number of cells (batteries)
set cell_number 4

# Discharge curve factor (dimensionless)
#
# This is a number between 0 and 1 describing how battery capacity
# maps to battery energy.  It describes the area under the voltage vs
# expended charge curve.
#
# Lithium batteries maintain the same voltage for most of their lives,
# making this area look like a rectangle.  The curve factor here would
# be close to 1.
#
# Alkaline Manganese Dioxide batteries have a nominally linear
# discharge curve, making their curve factor closer to 0.5.
set discharge_curve_factor 0.5

# Fresh battery voltage (Volts)
set fresh_voltage 1.5

# Dead voltage (Volts).  The battery reaches this voltage after
# expending its rated capacity.
set dead_voltage 0.8

# 1 mAh = 3.6 C
set rated_battery_capacity_c [expr $rated_battery_capacity_mah * 3.6]

# The battery energy is the area under the voltage vs expended charge
# curve.  Batteries have a minimum usable voltage, so the area under
# this curve will look like some shape on top of a rectangle.
set battery_energy [expr $cell_number * ($dead_voltage * $rated_battery_capacity_c + \
			  ($fresh_voltage - $dead_voltage) * $discharge_curve_factor * \
					       $rated_battery_capacity_c)]

# The average battery voltage is the total energy divided by the total
# expended charge.  Our batteries are in series, so use the charge
# expended by a single cell.
set average_battery_voltage [expr $battery_energy / $rated_battery_capacity_c]

# A switching regulator allows using battery energy at arbitrary
# voltages.  The energy output from the regulator will be the battery
# energy multiplied by an efficiency factor between 0 and 1.
set regulator_efficiency 0.9

# Voltage at the regulator output
set regulator_voltage 2

# The system battery capacity is the charge available to the system
# flowing out of the regulator voltage (coulombs)
set system_battery_capacity_c [expr $regulator_efficiency * $battery_energy / $regulator_voltage]

utils::add_section_header "Battery and regulator"

set data "Each cell contributes [format {%0.0f} [expr $battery_energy / $cell_number]] joules, "
append data "sourcing [format {%0.0f} $rated_battery_capacity_c] coulombs "
append data "([format {%0.0f} $rated_battery_capacity_mah] mAh)."
puts $data

puts "Total battery energy is [format {%0.0f} $battery_energy] joules from $cell_number cells."

set data "Batteries drain from [format {%0.1f} $fresh_voltage] volts to "
append data "[format {%0.1f} $dead_voltage] volts with a shape factor of "
append data "[format {%0.1f} $discharge_curve_factor]."
puts $data

set data "Average battery voltage for $cell_number cells in series is "
append data "[format {%0.2f} $average_battery_voltage] volts."
puts $data


set data "System battery capacity at $regulator_voltage volts is "
append data "[format {%0.0f} $system_battery_capacity_c] coulombs "
append data "([format {%0.0f} [expr $system_battery_capacity_c / 3.6]] mAh)."

# ---------------------------- LEDs -----------------------------------

# Time the LED is on during a dispense (seconds)
set led_dispense_time 0.7

# Number of dispenses (activations) per day
set dispenses_per_day 200

# Forward voltage of the LED
set led_voltage 2.1

# LED resistor
set led_resistor 200

# Average green LED current over the life of the dispenser
set average_led_current [expr ($average_battery_voltage - $led_voltage) / $led_resistor]

utils::add_section_header "LEDs"

set data "Average LED current is [format {%0.1f} [expr $average_led_current * 1000]] mA "
append data "for [format {%0.1f} $led_dispense_time] seconds, "
append data "[format {%0.0f} $dispenses_per_day] times a day."
puts $data

# Energy spent by LEDs each day (joules)
#
# The LED is connected directly to the batteries
set daily_led_energy [expr $dispenses_per_day * \
			 $led_dispense_time * \
			 $average_led_current * \
			  $average_battery_voltage]

# ------------------------ Capacitive sensor --------------------------
# Average capacitive sensor current (A)
set capsensor_current 0.0003

utils::add_section_header "Capacitive sensor"
set daily_capsensor_energy [expr 86400 * $capsensor_current * $regulator_voltage / $regulator_efficiency]

set data "Daily capactive sensor energy is [format {%0.0f} $daily_capsensor_energy] joules, "
append data "drawing [format {%0.0f} [expr $capsensor_current * 1e6]] uA continuously."
puts $data

# ----------------------------- Radio --------------------------------- 

# Radio current expended constantly (A)
set radio_static_current 0.000050

# Radio current expended during a dispense (A)
set radio_dispense_current 0.005

# Time spent in the high energy state of a dispense (seconds)
set radio_dispense_time 0.7 

# Energy expended by the radio during dispenses
set daily_radio_dispense_energy [expr $dispenses_per_day * $radio_dispense_time *\
				     $radio_dispense_current * $regulator_voltage /\
				     $regulator_efficiency]

set daily_radio_static_energy [expr 86400 * $radio_static_current * $regulator_voltage /\
				   $regulator_efficiency]

utils::add_section_header "Radio"

set data "Daily radio static energy is [format {%0.0f} $daily_radio_static_energy] joules, "
append data "drawing [format {%0.0f} [expr $radio_static_current * 1e6]] uA continuously."
puts $data

set data "Daily radio dynamic energy is [format {%0.0f} $daily_radio_dispense_energy] joules, "
append data "drawing [format {%0.0f} [expr $radio_dispense_current * 1e3]] mA "
append data "$dispenses_per_day times a day."
puts $data

# --------------------------- Total -----------------------------------

set total_daily_energy [expr $daily_led_energy + \
			    $daily_capsensor_energy +\
			    $daily_radio_dispense_energy +\
			    $daily_radio_static_energy]

utils::add_section_header "Total"

puts "Total daily energy expenditure is [format {%0.0f} $total_daily_energy] joules"
puts "LED share is [format {%0.0f} [expr $daily_led_energy / $total_daily_energy * 100]]%"
puts "Capacitive sensor share is [format {%0.0f} [expr $daily_capsensor_energy / $total_daily_energy * 100]]%"
puts "Radio static share is [format {%0.0f} [expr $daily_radio_static_energy / $total_daily_energy * 100]]%"
puts "Radio active share is [format {%0.0f} [expr $daily_radio_dispense_energy / $total_daily_energy * 100]]%"


set days_to_die [expr $battery_energy / $total_daily_energy]
set data  "Life expectancy is [format {%0.0f} $days_to_die] days "
append data "([format {%0.2f} [expr ($days_to_die / 365)]] years)."
puts $data
puts ""
