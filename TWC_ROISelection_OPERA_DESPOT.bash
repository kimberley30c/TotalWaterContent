#####################################
### FIRST PART: RUN BEFORE MATLAB ###
#####################################

# Register PDW to SPGRfa13 and apply to lesion mask

LesionR(){
    date +'%D %T'

##################################################
# STEP ONE: SET UP VARIABLES AND DIRECTORIES
    SUB=$1
    NUMSUB=$2
    WEEK=$3
    NUM=$(printf "%03.0f\n" $NUMSUB)
    # run_WCmaps... passes an already-padded number, but printf interprets 'decimal' numbers with leading zeros to be octal, so it changes the value unless the format is set to float
    #echo Subject: $SUB $NUM, Week $WEEK
    #File naming convention = start of file names:
    NAME='ORCH_'${SUB}'_'${NUM}'_W'${WEEK}'_'

    # Location for final outputs and where to find previously-made components
    # Should be same location as subjdir used in matlab, for octave component to work properly
    WC_DIR="/data/ubcitm10/ForWC/OPERA_DESPOT/ORCH_"$SUB"_"$NUM"/W"$WEEK
    if [ ! -e $WC_DIR ];then
	mkdir -p $WC_DIR
    fi
    
    # Location for files made and used in intermediate steps only (not needed externally)
    OUTPUT_DIR=$WC_DIR

    LESION="Lesion_Long"
    if [ -e "/data/chorus/ORCHESTRA/REG-MASKS/LONGITUDINAL/"$SUB"_"$NUM"/"$NAME"Lesion_Long_EditedJJS.nii.gz" ];then
	LESION="Lesion_Long_EditedJJS"
    fi
    LESIONORIG="/data/chorus/ORCHESTRA/REG-MASKS/LONGITUDINAL/"$SUB"_"$NUM"/"$NAME$LESION".nii.gz"
    LESIONR=$OUTPUT_DIR"/"$NAME$LESION"R.nii.gz"
    LESIONMASK=$OUTPUT_DIR"/"$NAME$LESION"R-thr10-bin.nii.gz"
    if [ -e $LESIONMASK ];then
	echo "Already have registered lesion mask: "$LESIONMASK
	return 1
    fi
    echo "Lesion mask to register: "$LESIONORIG

    echo DONE STEP ONE: SET-UP VARIABLES AND DIRECTORIES
    echo

##################################################
# STEP TWO: LINEAR REGISTRATION OF PDW TO SPGR AND APPLICATION TO LESION MASK

    flirt -in $WC_DIR"/"$NAME"PDW.nii.gz" -ref $WC_DIR"/"$NAME"SPGRfa13_ax.nii.gz" -omat $OUTPUT_DIR"/"$NAME"PDWR.mat" -out $OUTPUT_DIR"/"$NAME"PDWR.nii.gz"

    flirt -in $LESIONORIG -ref $WC_DIR"/"$NAME"SPGRfa13_ax.nii.gz" -applyxfm -init $OUTPUT_DIR"/"$NAME"PDWR.mat" -out $LESIONR

    date +'%D %T'
    echo DONE STEP TWO: LINEAR REGISTRATION OF PDW TO GRASE AND APPLICATION TO LESION MASK
    echo

##################################################
# STEP THREE: THRESHOLD AND BINARIZE LESION MASK
# Need lesion mask for fsl_reg --> this must be done before step four

    fslmaths $LESIONR -thr 10 -bin $LESIONMASK

    date +'%D %T'
    echo DONE STEP THREE: THRESHOLD AND BINARIZE LESION MASK
    echo
}







#####################################
### SECOND PART: RUN AFTER MATLAB ###
#####################################

# Register from SPGRfa13 space to MNI space, apply inverse to ROIs and process ROIs

ROIselect(){
    date +'%D %T'

##################################################
# STEP ONE: SET UP VARIABLES AND DIRECTORIES
    SUB=$1
    NUMSUB=$2
    WEEK=$3
    NUM=$(printf "%03.0f\n" $NUMSUB)
    # run_WCmaps... passes an already-padded number, but printf interprets 'decimal' numbers with leading zeros to be octal, so it changes the value unless the format is set to float
    echo Subject: $SUB $NUM, Week $WEEK
    #File naming convention = start of file names:
    NAME='ORCH_'${SUB}'_'${NUM}'_W'${WEEK}'_'

    LOGFILE=$4
	# Image to register to MNI standard space
    REGIMG=$5
    if [ $REGIMG != "SPGRfa13_ax" ];then REGIMG=$REGIMG"R";fi
    echo Registration image: $REGIMG
    # Standard space image to use
    if [ ! -z $6 ] && [ $6 = "BRAIN" ];then
	MNI="/usr/share/fsl/5.0/data/standard/MNI152_T1_2mm_brain"
    else
	MNI="/usr/share/fsl/5.0/data/standard/MNI152_T1_2mm"
    fi

    # Location for final outputs and where to find previously-made components
    # Should be same location as subjdir used in matlab, for octave component to work properly
    WC_DIR="/data/ubcitm10/ForWC/OPERA_DESPOT/ORCH_"$SUB"_"$NUM
    if [ ! -e $WC_DIR ];then
	mkdir $WC_DIR
    fi
    WC_DIR=$WC_DIR"/W"$WEEK
    if [ ! -e $WC_DIR ];then
	mkdir $WC_DIR
    fi

    if [ ! -e $WC_DIR"/"$NAME$REGIMG".nii"* ];then echo 'Registration Image ('$WC_DIR'/'$NAME$REGIMG'.nii.gz) does not exist. Exiting.'>>$LOGFILE;return 1;fi

    # Location for files made and used in intermediate steps only (not needed externally)
    OUTPUT_DIR=$WC_DIR

    LESION="Lesion_Long"
    LESIONMASK=$OUTPUT_DIR"/"$NAME$LESION"R-thr10-bin.nii.gz"
    if [ ! -e $LESIONMASK ];then
	LESION="Lesion_Long_EditedJJS"
	LESIONMASK=$OUTPUT_DIR"/"$NAME$LESION"R-thr10-bin.nii.gz"
    fi
    if [ ! -e $LESIONMASK ];then
	echo RUN FUNCTION LesionR FIRST TO REGISTER LESION MASK TO SPGRfa13 SPACE >>$LOGFILE
	return 1
    fi
    echo "Lesion Mask: "$LESIONMASK

    # Location of ROIs in MNI space
    ORIG_ROI_DIR="/data/chorus/ORCHESTRA/SCR1/KIMBERLEY/TWC_ROIs"

    # Location for ROIs warped to DESPOT space
    # Will overwrite ROIs made previously if in directory 'ROIs'
    ROI_DIR=$WC_DIR"/ROIs"
    if [ ! -e $ROI_DIR ];then
	mkdir $ROI_DIR
    else
	echo "OVERWRITING PREVIOUS ROIs" >>$LOGFILE
	rm -r $ROI_DIR"/"*
    fi
    echo ROI output directory: $ROI_DIR
    
    echo "Registration: $REGIMG to $MNI" > $WC_DIR"/registration.txt"
    
    
    echo DONE STEP ONE: SET-UP VARIABLES AND DIRECTORIES
    echo

##################################################
# STEP TWO: NONLINEAR REGISTRATION OF REGISTRATION IMAGE FROM SPGR SPACE TO MNI152
# Start with image already registered to SPGRfa13_ax
# Register with fsl_reg = FLIRT + FNIRT, as per Irene's procedure
    fsl_reg $WC_DIR"/"$NAME$REGIMG".nii.gz" $MNI $OUTPUT_DIR"/"$NAME$REGIMG"_warp1-to-MNI152" -fnirt "--inmask=$LESIONMASK"
    
    invwarp -w $OUTPUT_DIR"/"$NAME$REGIMG"_warp1-to-MNI152_warp" -o $OUTPUT_DIR"/"$NAME$REGIMG"_warp1-to-MNI152-invcoeff" -r $WC_DIR"/"$NAME$REGIMG".nii.gz"
    
    date +'%D %T'
    echo DONE STEP TWO: NONLINEAR REGISTRATION OF $REGIMG FROM SPGR SPACE TO MNI152
    echo

#################################################
# STEP THREE: PROCESS ROI MASKS
# Inverse warp ROIs to SPGR space
# Subtract ventricles, other CSF, and ventricles using pre-made masks
# Remove cortical GM from WM structures
# Saves both nifti and matlab files for each ROI to $ROI_DIR
    if [ ! -e $ROI_DIR"/InProg" ];then
	mkdir $ROI_DIR"/InProg"
    fi

    # The following only exist after running the matlab TWC program:
    VENTRICLEMASK=$WC_DIR"/Ventriclemask_dilated.nii.gz"
    CSFMASK=$WC_DIR"/3DT1R_brain_seg_0.nii.gz"
    CSFMASK_D=$WC_DIR"/3DT1R_brain_CSF_dil.nii.gz"
    WMMASK=$WC_DIR"/WMmask.nii"
    WMMASKINV=$WC_DIR"/WMmask_inv.nii"
    for ROI in cagmleft cagmright thgmleft thgmright pugmleft pugmright ccwm cstwmleft cstwmright ilfwmleft ilfwmright slfwmleft slfwmright;do
	ROIEXIT=0
	if [ -e $ORIG_ROI_DIR"/"$ROI".nii.gz" ]
	then
	    ROIINIT=$ROI_DIR"/InProg/"$NAME$ROI"_nolesionremoval.nii.gz"

	    applywarp --ref=$WC_DIR"/"$NAME$REGIMG".nii.gz" --in=$ORIG_ROI_DIR"/"$ROI".nii.gz" --warp=$OUTPUT_DIR"/"$NAME$REGIMG"_warp1-to-MNI152-invcoeff" --out=$ROIINIT --interp=nn
	    
	    if [ ! -e $CSFMASK_D ];then
		fslmaths $CSFMASK -dilM $CSFMASK_D
	    fi
	    
	    fslmaths $ROIINIT -sub $LESIONMASK -sub $VENTRICLEMASK -sub $CSFMASK_D -bin $ROI_DIR"/ROI_"$ROI".nii.gz"
	    if [[ $ROI == *"wm"* ]];then
		if [ ! -e $WMMASKINV ];then
		    fslmaths $WMMASK -binv $WMMASKINV
		fi
		fslmaths $ROI_DIR"/ROI_"$ROI".nii.gz" -sub $WMMASKINV -bin $ROI_DIR"/ROI_"$ROI".nii.gz"
	    fi
     	    gzip -d -f $ROI_DIR"/ROI_"$ROI".nii.gz"
	    matlab -nojvm -nodesktop -nosplash -r "addpath /data/chorus/ORCHESTRA/SCR1/KIMBERLEY/scripts/TWC_autoROI;try;nii2mat_ROI('$ROI_DIR/ROI_$ROI.nii',[],50);catch;disp('ERROR');exit(1);end;exit"
	    ROIEXIT=$?
	    if [ $ROIEXIT = 1 ];then
		echo "Not using $ROI ROI" >> $LOGFILE
	    fi
	    gzip -f $ROI_DIR"/ROI_"$ROI".nii"
	    echo Done $ROI
	else
	    echo No ROI file for $ROI. Skipping.
	fi
    done

    ROICOUNT=$(ls $ROI_DIR"/"*".mat" | wc -l)
    GMROICOUNT=$(ls $ROI_DIR"/"*"gm"*".mat" | wc -l)
    date +'%D %T'
    echo "DONE STEP THREE: APPLY INVERSE WARP TO ROI MASKS, SUBTRACT LESIONS/VENTRICLES/WRONG TISSUE TYPE AND CONVERT TO .MAT"
    printf "\n\n**********************************************************\n"
    printf '*** CHECK ROI PLACEMENT TO CONFIRM PROPER REGISTRATION ***\n'
    printf '**********************************************************\n'
    # CHANGE THIS FOR DIFFERENT DATA SETS
    printf '(Run "fslview '$WC_DIR'/'$NAME'T1WPRER.nii* -l "Red" -t 0.2 '$ROI_DIR'/*.nii* &")\n\n'$SUB' '$NUM' WEEK '$WEEK' ROI SELECTION COMPLETE\n\n\n'
    printf '**********************************************************\n' >>$LOGFILE
    printf '*** CHECK ROI PLACEMENT TO CONFIRM PROPER REGISTRATION ***\n' >>$LOGFILE
    printf '**********************************************************\n' >>$LOGFILE
    printf '(Run "fslview '$WC_DIR'/'$NAME'T1WPRER.nii* -l "Red" -t 0.2 '$ROI_DIR'/*.nii* &")\n--- '$ROICOUNT' ROIs CONVERTED TO .MAT FILES ('$GMROICOUNT' GM) ---\n' >>$LOGFILE
}

