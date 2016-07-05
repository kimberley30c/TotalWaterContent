#!/bin/bash
# Run selected WC processing programs for selected subjects (run CON and OPE separately because different subject numbers)

# Check input arguments
if [ $# -eq 0 ] ; then
    echo "run_WCmaps_OPERA_DESPOT usage:"
    echo "bash run_WCmaps_OPERA_DESPOT.bash SUB NUMSUBS WEEKS (STEPS) (MATSTEPS) (LOGFILE) (REGIMG) (MNI)"
    printf "OPTIONS: SUB = CON/OPE \n   NUMSUBS = # (subject number(s) - input multiple as '# # #') \n   WEEKS = # (input multiple as '# # #') \n"
    echo "   STEPS = # (processing steps to run: 1=Lesion Registration, 2=Matlab, 3=ROI selection, 4=octave; default none unless STEPS = \"\" => run all steps)"
    echo "   MATSTEPS = \"FirststepLaststep\" (1=uncorrected B1 map, 2=tissue mask, 3=prep for octave; default \"13\")"
    echo "   LOGFILE = text file to write summary to"
    echo "   REGIMG = T1WPRE/SPGRfa13_ax/FLAIR or other image registered to SPGR with registered filename ending in 'R' (image to register to MNI space; default SPGR)"
    echo "   MNI = BRAIN/SKULL (brain-extracted or not brain-extracted MNI image; default SKULL)"
    exit 1
elif [ $# -gt 8 ] ; then
    echo "run_WCmaps_OPERA_DESPOT: incorrect number of inputs, $# provided but maximum 8 allowed (SUB NUMSUBS WEEKS STEPS MATSTEPS LOGFILE REGIMG MNI)"
    exit 1
elif [ $# -lt 3 ]; then
    echo "run_WCmaps_OPERA_DESPOT: incorrect number of inputs, $# provided but at least 3 must be provided (provide SUB, NUMSUBS, WEEKS; STEPS, MATSTEPS, LOGFILE, REGIMG, MNI can be empty)"
    exit 1

fi;

#############################################
# STEP 1: SET UP DIRECTORIES AND VARIABLES

# File to save which steps were attempted during run and completion/failure status
DATE=$(date +'%Y_%m_%d')
LOGFILE=$6
if [ -z $LOGFILE ];then
    LOGFILE='/data/chorus/ORCHESTRA/SCR1/KIMBERLEY/scripts/text_outputs/OPERA_DESPOT/LOG_WCmaps_'$DATE'.txt' # change for other data sets
fi

# Assign input variables
SUB=$1
NUMSUBS=$2
WEEKS=$3

# Processing programs to run (0 = do not run; non-0 number = run):
if [ ! -z $4 ] && [ $4 != \"\" ];then
    RUNLESIONR=0;RUNMATLAB=0;RUNROI=0;RUNOCTAVE=0
    if [[ $4 == *"1"* ]];then RUNLESIONR=1;fi
    if [[ $4 == *"2"* ]];then RUNMATLAB=1;fi
    if [[ $4 == *"3"* ]];then RUNROI=1;fi
    if [[ $4 == *"4"* ]];then RUNOCTAVE=1;fi
else
    RUNLESIONR=1;RUNMATLAB=1;RUNROI=1;RUNOCTAVE=1
fi
# Matlab WC processing steps to run (from 1 to 3):
if [ ! -z $5 ] && [ $5 != \"\" ];then
    MATSTART=${5:0:1}
    MATSTOP=${5:1:2}
else
    MATSTART=1
    MATSTOP=3
fi
# Choose images to use for fsl_reg to MNI space
REGIMG0=$7
if [ $# -lt 7 ] || [ -z $REGIMG0 ] || [ $REGIMG0 = \"\" ];then REGIMG0="SPGRfa13_ax";fi
if [ -z $8 ] || [ $8 = \"\" ];then
    MNI=SKULL
else
    MNI=$8
fi

#############################################
# STEP 2: Load functions LesionR and ROIselect and set up log file
. /data/chorus/ORCHESTRA/RBIN/shell/WC/TWC_ROISelection_OPERA_DESPOT.bash # change for other data sets

printf "\n\n****************** NEW SESSION *******************" >>$LOGFILE
printf "\n   PROCESSING STEPS: $4 \n   MATLAB STEPS: $5 \n   REGIMG: $7 \n   REGISTER TO MNI WITH $MNI" >>$LOGFILE
printf "\n\n****************** NEW SESSION *******************"

#############################################
# STEP 3: Run processing
for NUMSUB in $NUMSUBS;do
    NUM=$(printf "%03d\n" $NUMSUB)
    for Wknum in $WEEKS;do
	Wk=$(printf "%03d\n" $Wknum)
	EXITCODE=0
	REGIMG=$REGIMG0 #Prevent adding 'R' to name repeatedly
	echo
	echo
	date +'%D %T'
	echo Subject: $SUB $NUM, Week $Wk
	printf "\n\n\n\n$(date +'%D %T')\nSubject: $SUB $NUM, Week $Wk\n" >>$LOGFILE
	if [ $RUNLESIONR -ne 0 ];then
	    printf "\nLesion Map Registration" >>$LOGFILE
	    2>>$LOGFILE LesionR $SUB $NUM $Wk
	fi
	if [ $RUNMATLAB -ne 0 ];then
	    printf "\n\nMATLAB\n" >>$LOGFILE
	    # change for other data sets
	    2>>$LOGFILE matlab -nojvm -nodesktop -nosplash -r "addpath /data/chorus/ORCHESTRA/RBIN/matlab/WC;subjdir=['/data/ubcitm10/ForWC/OPERA_DESPOT/ORCH_','$SUB','_','$NUM','/W','$Wk'];try;run_invivo_WC_processing_general_OPERA_DESPOT(subjdir,[$MATSTART $MATSTOP]);catch ERR;warning(ERR.identifier,ERR.message);exit(1);end;exit"
	    EXITCODE=$?
	    printf "\n\n"
	fi
	if [ $RUNROI -ne 0 ] && [ $EXITCODE -ne 1 ];then
	    printf "\nROI\n" >>$LOGFILE
	    2>>$LOGFILE ROIselect $SUB $NUM $Wk $LOGFILE $REGIMG $MNI
	fi
	if [ $RUNOCTAVE -ne 0 ] && [ $EXITCODE -ne 1 ];then
	    printf "\nOCTAVE\n" >>$LOGFILE
	    # change for other data sets
	    2>>$LOGFILE octave --path '/data/chorus/ORCHESTRA/RBIN/matlab/WC' --eval "subjdir=['/data/ubcitm10/ForWC/OPERA_DESPOT/ORCH_','$SUB','_','$NUM','/W','$Wk','/WC_results'];try;run_pPD_biasfield7it_kc(subjdir,'pPD_Biasfieldinputs.mat');catch;err=lasterror();warning(err.identifier, err.message);exit(1);end_try_catch;exit"
	fi
	printf "\nDONE: $SUB $NUM, Week $Wk\n" >>$LOGFILE
	printf "\nDONE: $SUB $NUM, Week $Wk\n\n"
    done
done

date +'%D %T'
date +'%D %T' >>$LOGFILE