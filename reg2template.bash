#!/bin/bash
# Script to convert Total Water Content map from .mat to .nii and register to template
# Adapted from Irene's /data/chorus/ORCHESTRA/SCR1/IRENE/LONGITUDINAL/GRASE/MWF_reg2template.sh

# Check input arguments
if [ $# -eq 0 ] ; then
    echo "reg2template usage:"
    echo "sh reg2template.sh SUB NUMSUBS WEEKS (STEPS)"
    printf "OPTIONS: SUB = CON/OPE \n   NUMSUBS = # (subject number(s) - input multiple as '# # #') \n   WEEKS = # (input multiple as '# # #') \n"
    echo "   STEPS = # (processing steps to run: 1=Conversion to NIfTI, 2=Register to OPERA template; default none unless STEPS = \"\" => run both steps)"
    exit 1
elif [ $# -gt 4 ] ; then
    echo "reg2template: incorrect number of inputs, $# provided but maximum 4 allowed (SUB NUMSUBS WEEKS STEPS)"
    exit 1
elif [ $# -lt 3 ]; then
    echo "reg2template: incorrect number of inputs, $# provided but at least 3 must be provided (provide SUB, NUMSUBS, WEEKS; STEPS can be empty)"
    exit 1

fi;

##################################################
# STEP ONE: SET UP VARIABLES AND DIRECTORIES

# File to save list of attempts and completion/failure during run
DATE=$(date +'%Y_%m_%d')
LOGFILE='/data/chorus/ORCHESTRA/SCR1/KIMBERLEY/scripts/text_outputs/OPERA_DESPOT/LOG_WCmaps2nii_'$DATE'.txt'


SUB=$1
NUMSUBS=$2
WEEKS=$3

# Processing programs to run (0 = do not run; non-0 number = run):
if [ ! -z $4 ] && [ $4 != \"\" ];then
    RUNNII=0;RUNREG=0;
    if [[ $4 == *"1"* ]];then RUNNII=1;fi
    if [[ $4 == *"2"* ]];then RUNREG=1;fi
else
    RUNNII=1;RUNREG=1
fi

printf "\n\n****************** NEW SESSION *******************" >>$LOGFILE
printf "\n\n****************** NEW SESSION *******************"

# ACTUAL PROCESSING STARTS HERE
for NUMSUB in $NUMSUBS;do
    NUM=$(printf "%03.0f\n" $NUMSUB)
    # run_WCmaps... passes an already-padded number, but printf interprets 'decimal' numbers with leading zeros to be octal, so it changes the value unless the format is set to float
    for WEEK in $WEEKS;do
	Wk=$(printf "%03d\n" $WEEK)
	echo
	echo
	date +'%D %T'
	echo Subject: $SUB $NUM, Week $Wk
	printf "\n\n\n\n$(date +'%D %T')\nSubject: $SUB $NUM, Week $Wk\n" >>$LOGFILE
	
	##################################################
	# STEP TWO: CONVERT TO NIFTI IF REQUESTED
	
	if [ $RUNNII -ne 0 ];then
		WCNII='/data/ubcitm10/ForWC/OPERA_DESPOT/ORCH_'${SUB}'_'${NUM}'/W'${Wk}'/WC_results/ORCH_'${SUB}'_'${NUM}'_W'${Wk}'_WCmap.nii'
		WCMAT='/data/ubcitm10/ForWC/OPERA_DESPOT/ORCH_'${SUB}'_'${NUM}'/W'${Wk}'/WC_results/WCmap.mat'
		SPGR='/data/ubcitm10/ForWC/OPERA_DESPOT/ORCH_'${SUB}'_'${NUM}'/W'${Wk}'/ORCH_'${SUB}'_'${NUM}'_W'${Wk}'_SPGRfa13_ax.nii'
		
	    if [ ! -e '${WCNII}'* ];then
		printf "\n\nCONVERSION TO NII\n" >>$LOGFILE
		echo CONVERTING TWC MAP FROM .MAT TO .NII
		2>>$LOGFILE matlab -nojvm -nodesktop -nosplash -r "addpath '/data/chorus/ORCHESTRA/RBIN/matlab/WC';nii='${SPGR}';mat='${WCMAT}';out='${WCNII}';try;load(mat);mat2nii_K(nii,WCmap,out);catch ERR;warning(ERR.identifier,ERR.message);exit(1);end;exit"
		2>>$LOGFILE gzip ${WCNII}
	    else
		printf "\n\nSKIPPING CONVERSION TO NII - previously completed\n" >>$LOGFILE
		echo SKIPPING CONVERSION OF TWC MAP FROM .MAT TO .NII - previously completed
	    fi
	    printf "\n\n"
	fi

	##################################################
	# STEP THREE: FLIRT TO TEMPLATE IF REQUESTED
	
	if [ $RUNREG -ne 0 ];then
		TEMPDIR='/data/chorus/ORCHESTRA/SCR1/lisat/opera_proc_rigid/${SUB}_${NUM}'
		NAME='ORCH_${SUB}_${NUM}_W${Wk}_'
		WCNII='/data/ubcitm10/ForWC/OPERA_DESPOT/ORCH_${SUB}_${NUM}/W${Wk}/WC_results/WCmap.nii.gz'
		WC2TEMPLATE='/data/ubcitm10/ForWC/OPERA/ORCH_${SUB}_${NUM}/W${Wk}/WC_results/ORCH_${SUB}_${NUM}_W${Wk}_TWCmap_flirt-to-template.nii.gz'
		REF=${TEMPDIR}'/atlas/avg.nii.gz'
		MATRIX=${TEMPDIR}'/GRASE/${NAME}GRASE/flirt_CR.mat'
		
	    if [ ! -e ${WC2TEMPLATE} ];then
		printf "\n\nREGISTRATION TO TEMPLATE SPACE\n" >>$LOGFILE
		echo REGISTERING TWC MAP TO TEMPLATE SPACE
		if [ $SUB = 'OPE' -a $NUM = '015' ];then
		    REF=${TEMPDIR}'/atlas/avg.nii.gz'
		    MATRIX=${TEMPDIR}'/GRASE/${NAME}GRASE/flirt_NMI.mat'
		elif [ $SUB = 'OPE' -a $NUM = '044' ];then
		    REF=${TEMPDIR}'../../opera_proc_affine/OPE_044/atlas/avg.nii.gz'
		    MATRIX=${TEMPDIR}'../../opera_proc_affine/OPE_044/GRASE/${NAME}GRASE/flirt_CR.mat'
		fi
		2>>$LOGFILE flirt -interp trilinear -ref $REF -in ${WCNII} -applyxfm -init $MATRIX -out ${WC2TEMPLATE}
	    else
			printf "\n\nSKIPPING REGISTRATION TO TEMPLATE SPACE - previously completed\n" >>$LOGFILE
			echo SKIPPING REGISTRATION OF TWC MAP TO TEMPLATE SPACE - previously completed
	    fi
	    printf "\n\n"
	fi
	printf "\nDONE: $SUB $NUM, Week $Wk\n" >>$LOGFILE
	printf "\nDONE: $SUB $NUM, Week $Wk\n\n"
    done
done

