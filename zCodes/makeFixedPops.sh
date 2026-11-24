#!/bin/bash

# ---------------------------------------------------------------
# -------- TUTORIAL NOTES (sll) ---------------------------------
# ---------------------------------------------------------------
# sll shell script template
# following tutorial: www.linux.com/training-tutorials/writing-simple-bash-script/
#
# bash Scripting Cheatsheet: https://devhints.io/bash
#
# Script needs to be executable, so make sure permissions are set correctly.
# To get rwx only by you:  % chmod 700 scriptname
#
# COMMAND LINE ARGUMENTS
# If use script name followed by arguments at the command line
# then each successive argument can be passed to commands in
# the script, proceeded by a $ and followed by the numerical
# order they appear in.  For example for script fooGalaxy :
#    % fooGalaxy MilkyWay.csv
# in the script then can use $1 anytime it needs MilkyWay.csv
#    % echo $1
# ---------------------------------------------------------------


# ---------------------------------------------------------------
# ORIGINAL : makeFixedPops
# SCRIPT   : makeFixedPops
# DATE     : 20 May 2021
# MODIFIED : 17 Mar 2022 (v2)
#
# This script takes a set of params.ini type files and
# makes successive fixed populations in COSMIC for
# the subpopulation files by STELLAR TYPE and by
# GALACTIC COMPONENT. These will be the inputs for
# making a FULL GALAXY.
#
# Aug 2026: Added automation to construct fixed-pop commands
#     based on the flags set in the cosmicRuntimeValues.txt
#     input file. Streamlines automation and reduces the
#     hacking that has to be done to adjust a given sim.
#     NB: MacOS only uses bash 3.2 (apparently Apple 
#     doesn't want to open CoreOS functions because of
#     the GPL license for bash 4). There is a nice way
#     to do this with associative arrays in bash 4, but
#     the code here works for bash 3.2, so has a clunkier
#     way of inputting the file.
#
# INPUTS: ---------------------
# Input files or command line arguments this script needs
#     * params.ini
#     * cosmicRuntimeValues.txt
#
# VARIABLES -------------------
# List of variables and what they are goes here for reference
#
# DATADIR = Directory where the fixed population files should be stored
# SECONDS = system var that counts time
# duration = current value of SECONDS
#
# ---------------------------------------------------------------

# ---------------------------------------------------
# VARIABLES AND SETUP
# ---------------------------------------------------

# setup standard index arrays to read in from cosmicRuntimeValues.txt 
keys=()
values=()
count=0

CONFIG_FILE="../buildFiles/cosmicRuntimeValues.txt"  # cosmicRuntimeValues.txt to read in, std directory structure

# Make sure the cosmicRuntimeValues.txt is there...
if [[ ! -f "$CONFIG_FILE" ]]; then
   echo "ERROR: '$CONFIG_FILE' not found."
   exit 1
fi


# ---------------------------------------------------
# TIMING STARTUP
# ---------------------------------------------------

NOW=$(date)
echo "START TIME: $NOW"
echo "   Started at: $(date +"%a %d %b %Y  %I:%M:%S %p %Z")"
echo "------------------------------"

(( SECONDS = 0 ))          ## set time at start of script


# ---------------------------------------------------
# READ IN FROM cosmicRuntimeValues.txt (line by line)
# ---------------------------------------------------
while IFS= read -r line || [[ -n "$line" ]]; do
   
   # Trim whitespace to check for comments or empty lines
   trimmed=$(echo "$line" | xargs 2>/dev/null)
   if [[ -z "$trimmed" ]] || [[ "$trimmed" == \#* ]]; then
       continue
   fi

   # find the delimiter =
   if [[ "$line" == *=* ]]; then
      key="${line%%=*}"
      value="${line#*=}"
   
      # Clean up leading/trailing spaces
      key=$(echo "$key" | xargs)
      value=$(echo "$value" | xargs)
   
      # store keys and values in parallel positions
      keys[$count]="$key"
      values[$count]="$value"
      count=$((count + 1))
   fi
   
done < "$CONFIG_FILE"
   
echo "cosmicRuntimeValues.txt successfully read"
echo "------------------------------"
echo


# ---------------------------------------------------
# HELPER FUNCTION -- get values based on key name
# ---------------------------------------------------
get_config() {
    local target_key="$1"
    local ii
    for ((ii=0; ii<count; ii++)); do
        if [[ "${keys[$ii]}" == "$target_key" ]]; then
            echo "${values[$ii]}"
            return 0
        fi
    done
    return 1 # return: failure if key not found
}


# ---------------------------------------------------
# HELPER FUNCTION -- run fixed populations for a
#   given galactic component flag (makeBulge,
#   makeThickDisk, or makeThinDisk)
# ---------------------------------------------------
run_component_pops() {
    local flag_name="$1"
    local flag_val
    flag_val="$(get_config "$flag_name")"

    local header_label=""
    local done_label=""
    local skip_label=""
    local ini_file=""
    local target_subdir=""

    # ---- This sets up values based on component for the ECHO and cosmic-pop call
    case "$flag_name" in
        makeBulge)
            header_label="BULGE"
            done_label="Bulge"
            skip_label="BULGE POPULATIONS"
            ini_file="../buildFiles/bulge_Params.ini"
            target_subdir="fixed_bulge"
            ;;
        makeThickDisk)
            header_label="THICK DISK"
            done_label="Thick Disk"
            skip_label="THICK DISK POPULATIONS"
            ini_file="../buildFiles/thick_Params.ini"
            target_subdir="fixed_thickDisk"
            ;;
        makeThinDisk)
            header_label="THIN DISK"
            done_label="Thin Disk"
            skip_label="THIN DISK POPULATIONS"
            ini_file="../buildFiles/thinDisk_Params.ini"
            target_subdir="fixed_thinDisk"
            ;;
        *)
            echo "ERROR: Unknown component flag '$flag_name'"
            return 1
            ;;
    esac

    if [[ "$flag_val" == "1" ]]; then
        echo "FIXED POPULATIONS FOR ${header_label}...."
        echo

        # ---- He + He Systems (kstar1 = 10; kstar2 = 10)
        if [[ "$(get_config "He_He [10,10]")" == "1" ]]; then
            echo "--> now working on He+He: 10 and 10..."
            (( duration1 = $SECONDS ))
            
            cosmic-pop --final-kstar1 10 --final-kstar2 10 --inifile "$ini_file" --Nstep 10000 --Niter 1000000000 -n 12 >> ../errLogs/log01_Fixed.log 2>> ../errLogs/err01_Fixed.log < /dev/null
            
            (( duration2 = $SECONDS - duration1 ))
            echo "   RUNTIME He+He = $(($duration2/86400)) DAY $((($duration2 % 86400)/3600)) HR $(((($duration2 % 86400)%3600)/60)) MIN $(((($duration2 % 86400)%3600)%60)) SEC"
            echo "   Finished at: $(date +"%a %d %b %Y  %I:%M:%S %p %Z")"
            echo
        else
            echo "--> [SKIPPED] He_He [10,10] flag == 0"
        fi
        
        # ---- CO + He Systems (kstar1 = 11; kstar2 = 10)
        if [[ "$(get_config "CO_He [11,10]")" == "1" ]]; then
            echo "now working on CO+He: 11 and 10..."
            (( duration1 = $SECONDS ))
            
            cosmic-pop --final-kstar1 11 --final-kstar2 10 --inifile "$ini_file" --Nstep 10000 --Niter 1000000000 -n 12 >> ../errLogs/log01_Fixed.log 2>> ../errLogs/err01_Fixed.log < /dev/null
            
            (( duration2 = $SECONDS - duration1 ))
            echo "   RUNTIME CO+He = $(($duration2/86400)) DAY $((($duration2 % 86400)/3600)) HR $(((($duration2 % 86400)%3600)/60)) MIN $(((($duration2 % 86400)%3600)%60)) SEC"
            echo "   Finished at: $(date +"%a %d %b %Y  %I:%M:%S %p %Z")"
            echo
        else
            echo "--> [SKIPPED] CO_He [11,10] flag == 0"
        fi
        
        # ---- CO + CO Systems (kstar1 = 11; kstar2 = 11)
        if [[ "$(get_config "CO_CO [11,11]")" == "1" ]]; then
            echo "now working on CO+CO: 11 and 11..."
            (( duration1 = $SECONDS ))
            
            cosmic-pop --final-kstar1 11 --final-kstar2 11 --inifile "$ini_file" --Nstep 10000 --Niter 1000000000 -n 12 >> ../errLogs/log01_Fixed.log 2>> ../errLogs/err01_Fixed.log < /dev/null
            
            (( duration2 = $SECONDS - duration1 ))
            echo "   RUNTIME CO+CO = $(($duration2/86400)) DAY $((($duration2 % 86400)/3600)) HR $(((($duration2 % 86400)%3600)/60)) MIN $(((($duration2 % 86400)%3600)%60)) SEC"
            echo "   Finished at: $(date +"%a %d %b %Y  %I:%M:%S %p %Z")"
            echo
        else
            echo "--> [SKIPPED] CO_CO [11,11] flag == 0"
        fi
        
        # ---- ONe + Any Systems (kstar1 = 12; kstar2 = 10,11,12)
        if [[ "$(get_config "ONe_He_ONe [12,10,12]")" == "1" ]]; then
            echo "now working on ONe+Any: 12 and 10 11 12..."
            (( duration1 = $SECONDS ))
            
            cosmic-pop --final-kstar1 12 --final-kstar2 10 12 --inifile "$ini_file" --Nstep 10000 --Niter 1000000000 -n 12 >> ../errLogs/log01_Fixed.log 2>> ../errLogs/err01_Fixed.log < /dev/null
            
            (( duration2 = $SECONDS - duration1 ))
            echo "   RUNTIME ONe+any = $(($duration2/86400)) DAY $((($duration2 % 86400)/3600)) HR $(((($duration2 % 86400)%3600)/60)) MIN $(((($duration2 % 86400)%3600)%60)) SEC"
            echo "   Finished at: $(date +"%a %d %b %Y  %I:%M:%S %p %Z")"
            echo
        else
            echo "--> [SKIPPED] ONe_He_ONe [12,10,12] flag == 0"
        fi
        
        # ---- NS + WD Systems (kstar1 = 13; kstar2 = 10,11,12)
        if [[ "$(get_config "NS_He_ONe [13,10,12]")" == "1" ]]; then
            echo "now working on NS+WD: 13 and 10,11,12..."
            (( duration1 = $SECONDS ))
            
            cosmic-pop --final-kstar1 13 --final-kstar2 10 12 --inifile "$ini_file" --Nstep 100000 --Niter 1000000000 -n 12 >> ../errLogs/log01_Fixed.log 2>> ../errLogs/err01_Fixed.log < /dev/null
            
            (( duration2 = $SECONDS - duration1 ))
            echo "   RUNTIME NS+WD = $(($duration2/86400)) DAY $((($duration2 % 86400)/3600)) HR $(((($duration2 % 86400)%3600)/60)) MIN $(((($duration2 % 86400)%3600)%60)) SEC"
            echo "   Finished at: $(date +"%a %d %b %Y  %I:%M:%S %p %Z")"
            echo
        else
            echo "--> [SKIPPED] NS_He_ONe [13,10,12] flag == 0"
        fi
        
        # ---- BH + WD Systems (kstar1 = 14; kstar2 = 10,11,12)
        if [[ "$(get_config "BH_He_ONe [14,10,12]")" == "1" ]]; then
            echo "now working on BH+WD: 14 and 10,11,12..."
            (( duration1 = $SECONDS ))
            
            cosmic-pop --final-kstar1 14 --final-kstar2 10 12 --inifile "$ini_file" --Nstep 100000 --Niter 1000000000 -n 12 >> ../errLogs/log01_Fixed.log 2>> ../errLogs/err01_Fixed.log < /dev/null
            
            (( duration2 = $SECONDS - duration1 ))
            echo "   RUNTIME BH+WD = $(($duration2/86400)) DAY $((($duration2 % 86400)/3600)) HR $(((($duration2 % 86400)%3600)/60)) MIN $(((($duration2 % 86400)%3600)%60)) SEC"
            echo "   Finished at: $(date +"%a %d %b %Y  %I:%M:%S %p %Z")"
            echo
        else
            echo "--> [SKIPPED] BH_He_ONe [14,10,12] flag == 0"
        fi
        
        # ---- NS + NS Systems (kstar1 = 13; kstar2 = 13)
        if [[ "$(get_config "NS_NS [13,13]")" == "1" ]]; then
            echo "now working on NS+NS: 13 and 13..."
            (( duration1 = $SECONDS ))
            
            cosmic-pop --final-kstar1 13 --final-kstar2 13 --inifile "$ini_file" --Nstep 100000 --Niter 1000000000 -n 12 >> ../errLogs/log01_Fixed.log 2>> ../errLogs/err01_Fixed.log < /dev/null
            
            (( duration2 = $SECONDS - duration1 ))
            echo "   RUNTIME NS+NS = $(($duration2/86400)) DAY $((($duration2 % 86400)/3600)) HR $(((($duration2 % 86400)%3600)/60)) MIN $(((($duration2 % 86400)%3600)%60)) SEC"
            echo "   Finished at: $(date +"%a %d %b %Y  %I:%M:%S %p %Z")"
            echo
        else
            echo "--> [SKIPPED] NS_NS [13,13] flag == 0"
        fi
        
        # ---- BH + NS Systems (kstar1 = 14; kstar2 = 13)
        if [[ "$(get_config "BH_NS [14,13]")" == "1" ]]; then
            echo "now working on BH+NS: 14 and 13..."
            (( duration1 = $SECONDS ))
            
            cosmic-pop --final-kstar1 14 --final-kstar2 13 --inifile "$ini_file" --Nstep 100000 --Niter 1000000000 -n 12 >> ../errLogs/log01_Fixed.log 2>> ../errLogs/err01_Fixed.log < /dev/null
            
            (( duration2 = $SECONDS - duration1 ))
            echo "   RUNTIME BH+NS = $(($duration2/86400)) DAY $((($duration2 % 86400)/3600)) HR $(((($duration2 % 86400)%3600)/60)) MIN $(((($duration2 % 86400)%3600)%60)) SEC"
            echo "   Finished at: $(date +"%a %d %b %Y  %I:%M:%S %p %Z")"
            echo
        else
            echo "--> [SKIPPED] BH_NS [14,13] flag == 0"
        fi
        
        # ---- BH + BH Systems (kstar1 = 14; kstar2 = 14)
        if [[ "$(get_config "BH_BH [14,14]")" == "1" ]]; then
            echo "now working on BH+BH: 14 and 14..."
            (( duration1 = $SECONDS ))
            
            cosmic-pop --final-kstar1 14 --final-kstar2 14 --inifile "$ini_file" --Nstep 10000 --Niter 1000000000 -n 12 >> ../errLogs/log01_Fixed.log 2>> ../errLogs/err01_Fixed.log < /dev/null
            
            (( duration2 = $SECONDS - duration1 ))
            echo "   RUNTIME BH+BH = $(($duration2/86400)) DAY $((($duration2 % 86400)/3600)) HR $(((($duration2 % 86400)%3600)/60)) MIN $(((($duration2 % 86400)%3600)%60)) SEC"
            echo "   Finished at: $(date +"%a %d %b %Y  %I:%M:%S %p %Z")"
            echo
        else
            echo "--> [SKIPPED] BH_BH [14,14] flag == 0"
        fi
        
        # --- note use of MV instead of mv -- how I have my unix set up.
        #     for standard unix use:
        #  mv ./dat_* ./fixed_bulge/.
        #  mv ./log_* ./fixed_bulge/.
        #
        #     for my unix shell environemnt use:
        #  MV ./dat_* ../fixed/fixed_bulge/.
        #  MV ./log_* ../fixed/fixed_bulge/.
        # Move generated files to the component directory
        if [[ "$(get_config "sllUNIX")" == "1" ]]; then
            MV ./dat_* "../fixed/${target_subdir}/."
            MV ./log_* "../fixed/${target_subdir}/."
        else
            mv ./dat_* "./${target_subdir}/."
            mv ./log_* "./${target_subdir}/."
        fi
        
        echo
        echo "${done_label} complete."
        echo
        echo "------------------------------"
        echo
    else
        echo "--> [SKIPPED ${skip_label}] ${flag_name} == 0"
    fi
}


# ---------------------------------------------------
# RUN GALACTIC COMPONENT POPULATIONS
# ---------------------------------------------------
run_component_pops "makeBulge"
run_component_pops "makeThickDisk"
run_component_pops "makeThinDisk"


# ---------------------------------------------------
# END OF SCRIPT
# ---------------------------------------------------

NOW=$(date)
echo "FINISH TIME: $(date +"%a %d %b %Y  %I:%M:%S %p %Z")"

(( duration = $SECONDS ))            ## set time at end of script
echo "TOTAL RUNTIME = $(($duration/86400)) DAY $((($duration % 86400)/3600)) HR $(((($duration % 86400)%3600)/60)) MIN $(((($duration % 86400)%3600)%60)) SEC"
echo
echo "------------------------------"
echo "All done!"