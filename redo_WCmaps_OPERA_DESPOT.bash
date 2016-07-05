#!/bin/bash
# Re-run selected WC processing programs for selected subjects (run CON and OPE separately because different subject numbers)

# Check input arguments
if [ $# -eq 0 ] ; then
    echo "redo_WCmaps_OPERA_DESPOT usage:"
    echo "bash redo_WCmaps_OPERA_DESPOT.bash SUB NUMSUBS WEEKS (STEPS) (MATSTEPS) (REGIMG) (MNI)"
    printf "OPTIONS: SUB = CON/OPE \n   NUMSUBS = # (subject number(s)) \n   WEEKS = # \n"
    echo "   STEPS = # (processing steps to run: 1=Lesion Registration, 2=Matlab, 3=ROI selection, 4=octave; default none)"
    echo "   MATSTEPS = \"FirststepLaststep\" (1=uncorrected B1 map, 2=tissue mask, 3=prep for octave; default 1:3)"
    echo "   REGIMG = T1WPRE/SPGRfa13_ax/FLAIR or other image registered to SPGR with registered filename ending in 'R' (image to register to MNI space)"
    echo "   MNI = BRAIN/SKULL (brain-extracted or not brain-extracted MNI image; default SKULL)"
    exit 1
elif [ $# -gt 7 ] ; then
    echo "redo_WCmaps_OPERA_DESPOT: incorrect number of inputs, $# provided but maximum 7 allowed (SUB NUMSUBS WEEKS STEPS MATSTEPS REGIMG MNI)"
    exit 1
elif [ $# -lt 3 ]; then
    echo "redo_WCmaps_OPERA_DESPOT: incorrect number of inputs, $# provided but at least 3 required (provide SUB, NUMSUBS, WEEKS; STEPS, MATSTEPS, REGIMG, MNI can be empty)"
    exit 1
fi;

##################################################
# STEP ONE: SET UP VARIABLES AND DIRECTORIES

# Assign input variables
SUB=$1
NUMSUBS=$2
WEEKS=$3
STEPS=$4
MATSTEPS=$5
REGIMG0=$6

# Processing programs to run (0 = do not run; 1 = run):
if [ ! -z $4 ];then
    RUNLESIONR=0;RUNMATLAB=0;RUNROI=0;RUNOCTAVE=0
    if [[ $4 == *"1"* ]];then RUNLESIONR=1;fi
    if [[ $4 == *"2"* ]];then RUNMATLAB=1;fi
    if [[ $4 == *"3"* ]];then RUNROI=1;fi
    if [[ $4 == *"4"* ]];then RUNOCTAVE=1;fi
else
    RUNLESIONR=1;RUNMATLAB=1;RUNROI=1;RUNOCTAVE=1
fi
# Matlab WC processing steps to run (from 1 to 3):
if [ ! -z $5 ];then
    MATSTART=${5:0:1}
    MATSTOP=${5:1:2}
else
    MATSTART=1
    MATSTOP=3
fi

##################################################
# STEP TWO: COPY EACH DATASET TO A BACKUP VERSION AND REMOVE FILES TO BE REMADE

for NUMSUB in $NUMSUBS;do
    NUM=$(printf "%03d\n" $NUMSUB)
    for Wknum in $WEEKS;do
	Wk=$(printf "%03d\n" $Wknum)
	WKDIR="/data/ubcitm10/ForWC/OPERA_DESPOT/ORCH_${SUB}_${NUM}/W${Wk}"	# change for other data sets

	# Move existing version to different directory and restart from original
	for i in $(seq 0 10);do
	    NEWWKDIR=${WKDIR}"_${i}"
	    if [ ! -d $NEWWKDIR ];then
		mv $WKDIR $NEWWKDIR
		cp -r $NEWWKDIR $WKDIR
		break
	    fi
	done
	if [ $i -eq 10 ];then
	    echo "10 versions of Subject ${SUB} ${NUM}, Week ${Wk} already exist. Increase count in script to prevent over-writing other versions."
	    exit
	fi
	
	# Remove files that would skip steps to be run (Matlab runs a try/catch block for these steps, and skips processing if they already exist)
	if [ $RUNMATLAB -eq 1 -a 2 -ge $MATSTART -a 2 -le $MATSTOP ];then
	    rm $WKDIR"/"*"mask"*
	    rm $WKDIR"/3DT1R"*
	fi
	# Remove final results from previous run so no old results are mistaken for new
	rm $WKDIR"/WC_results/"*"output"* $WKDIR"/WC_results/WCmap."* $WKDIR"/WC_results/ORCH"*".nii"* # change for other data sets
    done
done

##################################################
# STEP THREE: CALL run_WCmaps_OPERA_DESPOT SCRIPT FOR ALL DATASETS AT ONCE
DATE=$(date +'%Y_%m_%d')
LOGFILE='/data/chorus/ORCHESTRA/SCR1/KIMBERLEY/scripts/text_outputs/OPERA_DESPOT/LOG_WCmaps_'$DATE'_reprocess.txt'	# change for other data sets
if [ -z $4 ];then STEPS=\"\";fi
if [ -z $5 ];then MATSTEPS=\"\";fi
if [ -z $6 ];then REGIMG0=\"\";fi
bash /data/chorus/ORCHESTRA/RBIN/shell/WC/run_WCmaps_OPERA_DESPOT.bash "$1" "$2" "$3" "$STEPS" "$MATSTEPS" "$LOGFILE" "$REGIMG0" "$7"	# change for other data sets