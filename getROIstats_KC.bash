#!/bin/bash

OUTDIR=/data/ubcitm10/ForWC/OPERA_DESPOT/WCstats_KC
MASKDIR=/data/chorus/ORCHESTRA/SCR1/IRENE/LONGITUDINAL/SPGRfa13

#LONGITUDINAL?
#OPE NUMSUBS=1 2 4 6 7 8 9 10 11 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 58 59 61 62 63
#CON NUMSUBS=1 3 4 5 6 7 8 9 12 13 14 15 17 19 22 24 27 28 29 31 33 34 38 39

#SUBSTUDY ONLY
#OPE NUMSUBS=2 4 6 7 9 10 14 15 16 18 19 20 21 22 23 24 25 26 28 32 33 35 36 37 38 39 41 43 45 46 51 52 53 55 58 59 60 61 62
#CON NUMSUBS=1 2 3 4 5 6 7 8 9 12 13 14 15 17 19 22 24 26 27 28 29 31 33 34 38 39

SUB=CON

for NUMSUB in 1 3 4 5 6 7 8 9 12 13 14 15 17 19 22 24 27 28 29 31 33 34 38 39;do
    NUM=$(printf "%03d\n" $NUMSUB);
    #echo ${SUB}_${NUM} >> $OUTDIR/IDnames_${SUB}.out
    for Wk in 000 048 096;do
	NAME='ORCH_${SUB}_${NUM}_'
	#INPUT=/data/ubcitm10/ForWC/OPERA/ORCH_${SUB}_${NUM}/W${Wk}/WC_results/${NAME}W${Wk}_TWCmap_flirt-to-template.nii.gz
	INPUT=/data/chorus/ORCHESTRA/SCR1/lisat/opera_proc_rigid/WCM/${NAME}W${Wk}_WCmap_in_template_l-interp.nii.gz
	if [ -e $INPUT ];then
	    echo \'${SUB}_${NUM}\' \'W${Wk}\' >> $OUTDIR/IDnames_${SUB}withWEEK.out
	    for ROI in ATR CST ILF SLF;do
		#fslstats $INPUT -k $MASKDIR/${NAME}${ROI}mask_chop.nii -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_${ROI}_${SUB}_W${Wk}.out
		fslstats $INPUT -k $MASKDIR/${NAME}${ROI}mask_chop.nii -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_${ROI}_${SUB}.out
		#printf ""
	    done
	    #fslstats $INPUT -k $MASKDIR/${NAME}MNmask_ero.nii -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_MN_${SUB}_W${Wk}.out
	    fslstats $INPUT -k $MASKDIR/${NAME}MNmask_ero.nii -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_MN_${SUB}.out
	    #fslstats $INPUT -k $MASKDIR/${NAME}CCmask_sl10.nii -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_CC_${SUB}_W${Wk}.out
	    fslstats $INPUT -k $MASKDIR/${NAME}CCmask_sl10.nii -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_CC_${SUB}.out
	    #fslstats $INPUT -k $MASKDIR/../WBmask/${NAME}avg_WB_limit.nii.gz -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_WB_${SUB}_W${Wk}.out
	    fslstats $INPUT -k $MASKDIR/../WBmask/${NAME}avg_WB_limit.nii.gz -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_WB_${SUB}.out
	    #fslstats $INPUT -k /data/ubcitm10/ForWC/OPERA/WBmask_middle/${NAME}avg_WB_limit_middle.nii.gz -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_WB_middle_${SUB}_W${Wk}.out
	    fslstats $INPUT -k /data/ubcitm10/ForWC/OPERA/WBmask_middle/ORCH_${SUB}_${NUM}_avg_WB_limit_middle.nii.gz -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_WB_middle_${SUB}.out
	    if [ $SUB = 'OPE' ];then
		#fslstats $INPUT -k $MASKDIR/../NAWMmask/${NAME}avg_NAWM_limit.nii -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_NAWM_${SUB}_W${Wk}.out
		fslstats $INPUT -k $MASKDIR/../NAWMmask/${NAME}avg_NAWM_limit.nii -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_NAWM_${SUB}.out
		LESIONS=${MASKDIR}/../LESION/${NAME}Lesion_flirt-to-template_mul_thr_limit
		if [[ ' 8 9 11 16 17 25 26 27 34 37 40 41 42 43 50 54 ' = *' ${NUMSUB} '* ]];then
		    LESIONS=$LESIONS'_E'
		fi
		LESIONS=$LESIONS'.nii'
		#fslstats $INPUT -k $LESIONS -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_LES_${SUB}_W${Wk}.out
		fslstats $INPUT -k $LESIONS -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_LES_${SUB}.out
	    else
		#fslstats $INPUT -k $MASKDIR/../NWMmask/${NAME}avg_ero2D_limit.nii -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_NWM_${SUB}_W${Wk}.out
		fslstats $INPUT -k $MASKDIR/../NWMmask/${NAME}avg_ero2D_limit.nii -m -p 50 -p 25 -p 75 >> $OUTDIR/stats_NWM_${SUB}.out
		#printf ""
	    fi
	else
	    echo "Skipping stats for $SUB $NUM, Week ${Wk}. $INPUT does not exist"
	fi
    done
done