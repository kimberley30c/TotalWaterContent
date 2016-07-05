#!/bin/bash

# Check input arguments
if [ $# -eq 0 ] ; then
    echo "cp_OPERA_DESPOT usage:"
    echo "bash cp_OPERA_DESPOT.bash SUB NUMSUBS WEEKS"
    printf "OPTIONS: SUB = CON/OPE \n   NUMSUBS = # (subject number(s) - input multiple as '# # #') \n   WEEKS = # (input multiple as '# # #') \n"
   exit 1
elif [ $# -ne 3 ] ; then
    echo "cp_OPERA_DESPOT: incorrect number of inputs, $# provided but 3 required (SUB NUMSUBS WEEKS)"
    exit 1
fi;

#SET UP DIRECTORIES AND VARIABLES
#DESPOT='/data/chorus/ORCHESTRA/SCR1/SHANNON/mcDESPOT' # location of M0 and T1 maps
DESPOT='/data/chorus/ORCHESTRA/SCR1/KIMBERLEY/OPERA/DESPOT1' # location of M0 and T1 maps
OD='/data/chorus/ORCHESTRA/ORIG-DATA' # location of SPGRfa13, PDW and T1W images
MAPS='/data/chorus/ORCHESTRA/MAPS' # location of SWI R2* and Mag maps
WC='/data/ubcitm10/ForWC/OPERA_DESPOT' # destination

SUB=$1
NUMSUBS=$2
WEEKS=$3

#DO THE PROCESSING (COPY/AXIALIZE/REGISTER AS NEEDED)
for NUMSUB in $NUMSUBS;do
    NUM=$(printf "%03d\n" $NUMSUB)
    for WEEK in $WEEKS;do
		WK=$(printf "%03d\n" $WEEK)
		WCWK=$WC'/ORCH_'${SUB}'_'$NUM'/W'$WK
		NAME='ORCH_'${SUB}'_'${NUM}'_W'${WK}'_' # naming convention - change for other data sets
		mkdir -p $WCWK'/WC_results'
		DESPWK=$DESPOT'/'${SUB}'_'${NUM}'/W'*${WK}
#		DESPWK=$DESPOT'/W'*${WK}'/'${SUB}'_'${NUM} #     option for Shannon's mcDESPOT naming convention

		#	need M0 as basis for TWC map 
		cp $DESPWK'/'*'MoMap.nii.gz' $WCWK'/'${NAME}'Mo.nii.gz' || echo SKIPPED Mo
		#	option for mcDESPOT naming conventions:
#		cp $DESPWK'/singleMo_spgr_s0_s92.nii.gz' $WCWK'/'${NAME}'Mo.nii.gz' || echo SKIPPED Mo
		if [ -e $WCWK'/'${NAME}'Mo.nii.gz' ];then
			fslswapdim $WCWK'/'${NAME}'Mo.nii.gz' -z -x y $WCWK'/'${NAME}'Mo_ax.nii.gz'
			#	need Slicelims.txt for octave fitting
		    DIMS=($(fslstats $WCWK'/'${NAME}'Mo_ax.nii.gz' -w))
		    echo $((${DIMS[4]}+1)) $((${DIMS[4]}+1+${DIMS[5]})) > $WCWK'/WC_results/Slicelims.txt'
		fi

		#	need T1 for octave fitting (1/T1 vs 1/TWC)
		cp $DESPWK'/'*'T1Map.nii.gz' $WCWK'/'${NAME}'T1map.nii.gz' || echo SKIPPED T1 MAP
		#	option for mcDESPOT naming conventions:
#		cp $DESPWK'/singleT1_s0_s92.nii.gz' $WCWK'/'${NAME}'T1map.nii.gz' || echo SKIPPED T1 MAP
		if [ -e $WCWK'/'${NAME}'T1map.nii.gz' ];then
			fslswapdim $WCWK'/'${NAME}'T1map.nii.gz' -z -x y $WCWK'/'${NAME}'T1map_ax.nii.gz'
		fi

		#	need SPGRfa13 for ventricle masks and co-registration
		cp $OD'/'${SUB}'_'${NUM}'/'${NAME}'SPGRfa13.nii.gz' $WCWK || echo SKIPPED SPGRfa13
		if [ -e $WCWK'/'${NAME}'SPGRfa13.nii.gz' ];then
		    fslswapdim $WCWK'/'${NAME}'SPGRfa13.nii.gz' -z -x y $WCWK'/'${NAME}'SPGRfa13_ax.nii.gz'
		fi

		#       need lesion mask for FNIRT to MNI space




		#####################################################
		###  *** INSERT CODE TO COPY LESION MASK HERE *** ###
		#####################################################
		# OPERA: get directly later on




		#	need PDW to transform lesion mask from PDW space to SPGRfa13 space - register later
		cp $OD'/'${SUB}'_'${NUM}'/'${NAME}'PDW.nii.gz' $WCWK || echo SKIPPED PDW
	
		#	need anatomical T1W for making tissue mask - do registration immediately
		cp $OD'/'${SUB}'_'${NUM}'/'${NAME}'T1WPRE.nii.gz' $WCWK || echo SKIPPED T1WPRE
		if [ -e $WCWK'/'${NAME}'T1WPRE.nii.gz' ];then
			flirt -in $WCWK'/'${NAME}'T1WPRE.nii.gz' -ref $WCWK'/'${NAME}'SPGRfa13_ax.nii.gz' -out $WCWK'/'${NAME}'T1WPRER.nii.gz' -omat $WCWK'/'${NAME}'T1WPRER.mat' -bins 256 -cost corratio -searchrx 0 0 -searchry 0 0 -searchrz 0 0 -dof 6  -interp sinc -sincwidth 7 -sincwindow hanning
		fi

		#	need R2* for T2* correction, Mag for registration - do registration immediately
		if [ ! -e $WCWK'/'${NAME}'SWI_R2starR.nii' ];then
			R2STAR=$MAPS'/R2star/'${NAME}'SWI_R2star.nii'
			if [ -e $R2STAR ];then
				cp $R2STAR $WCWK
				cp $MAPS'/R2star/'${NAME}'SWI_Mag_cor.nii' $WCWK
			else
				# Some R2star maps missing 'W' before Week number
				cp $MAPS'/R2star/ORCH_'${SUB}'_'${NUM}'_'${WK}'_SWI_R2star.nii' $WCWK'/'${NAME}'SWI_R2star.nii' || echo "SKIPPED R2*"
				cp $MAPS'/R2star/ORCH_'${SUB}'_'${NUM}'_'${WK}'_SWI_Mag_cor.nii' $WCWK'/'${NAME}'SWI_Mag_cor.nii' || echo "SKIPPED SWI Mag"
			fi
		
			if [ -e $WCWK'/'${NAME}'SWI_R2star.nii' ];then
				flirt -in $WCWK'/'${NAME}'SWI_Mag_cor.nii' -ref $WCWK'/'${NAME}'SPGRfa13_ax.nii.gz' -out $WCWK'/'${NAME}'SWI_Mag_corR.nii' -omat $WCWK'/'${NAME}'SWI_Mag_corR.mat'
				flirt -in $WCWK'/'${NAME}'SWI_R2star.nii' -ref $WCWK'/'${NAME}'SPGRfa13_ax.nii.gz' -applyxfm -init $WCWK'/'${NAME}'SWI_Mag_corR.mat' -out $WCWK'/'${NAME}'SWI_R2starR.nii'
			fi
		fi

		echo DONE COPYING ${NAME}
    done
done