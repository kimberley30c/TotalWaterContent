Total Water Content Mapping for OPERA based on DESPOT1-HIFI data and corrected with SWI data
7 June 2016, Kimberley Chang
——————————————————————————————————————

CONTENTS:
- PROGRAMS
- IMAGES AND MAPS REQUIRED
- ANALYSIS STEPS (includes code to run)
- OTHER NOTES
- FINAL VERSIONS OF WC MAPS
- HISTORICAL VERSIONS OF WC MAPS
- ADAPTING SCRIPTS TO OTHER STUDIES


PROGRAMS
- in order of use
- only includes Matlab functions called by shell scripts or directly in Matlab, not ones called within other Matlab functions
- scripts are in /data/chorus/ORCHESTRA/RBIN/(matlab or shell)/WC unless otherwise specified
(if any scripts are missing, look in /data/chorus/ORCHESTRA/SCR1/KIMBERLEY/scripts/TWC_autoROI)

	- cp_OPERA_DESPOT.bash
	- /data/workgroup/matlab/spm8/spm and /data/ubcitm10/Sandra/ALVIN_ventricles/ALVIN_v1p06.m
	- run_WCmaps_OPERA_DESPOT.bash
	- TWC_ROISelection_OPERA_DESPOT.bash
	- run_invivo_WC_processing_general_OPERA_DESPOT.m
	- nii2mat_ROI.m
	- run_pPD_biasfield7it_kc.m
	- check_wc_maps.m
	- (optional) redo_WCmaps_OPERA_DESPOT.bash
	- (optional) reg2template.sh
	- (optional) getROIstats_KC.bash
	- (optional) GetLesionWCValues.m



IMAGES AND MAPS REQUIRED (in subject directory)
	- *SPGRfa13_ax*
	- *T1WPRE*
	- *Mo_ax*
	- *T1map_ax
	- *Lesion_Long*
	- *PDW*
	- *SWI_Mag_cor*
	- *SWI_R2star*



ANALYSIS STEPS
	‘*’ indicates objectives of step
	‘>’ indicates code to run
	‘-‘ indicates other notes
	code lines assume you are in the script’s directory (see PROGRAMS)

*** Can run steps 1 and 3-6 consecutively for several subjects and/or timepoints by replacing NUM and/or WK by a list of numbers in single quotations, e.g. ‘1 2 4 9’, ‘0 24 48 96’, etc. (run without any arguments to see all options) ***

(1) Get data and co-register
	* Collect images and maps from different locations
	* Put all images in SPGRfa13 space (correctly oriented, aligned & same resolution), except PDW (done later)
	* Make file (subjdir)/WC_results/Slicelims.txt containing lowest and highest non-zero slice for fitting
	> bash cp_OPERA_DESPOT.bash SUB NUM WK
	- Registers T1W and SWI to SPGRfa13 with FLIRT
	- DESPOT1 maps (T1 and Mo) are already in SPGR space
	- Converts SPGR and DESPOT1 maps to axial orientation

(2) Make ventricle masks
	* To define CSF for normalization and removal from tissue masks
	> gunzip /data/ubcitm10/ForWC/OPERA_DESPOT/*/*/*SPGRfa13_ax.nii.gz
	> matlab
		>> path(path,'/data/workgroup/matlab/spm8')
		>> spm
			>>> (select FMRI)
			>>> (select Utils > Run M-file)
			>>> (select /data/ubcitm10/Sandra/ALVIN_ventricles/ALVIN_v1p06.m, then Done)
			>>> (select ‘No’ for ‘Have you already segmented your images…’)
			>>> (select ALL axial SPGRfa13 images to make ventricle masks on, then Done)
			>>> (select /data/ubcitm10/Sandra/ALVIN_ventricles/ALVIN_mask_v1.img, then Done)
			>>> (select ’No’ for ‘Save volumes to text file?’ unless needed for rough verification that masks are of appropriate size. If ‘Yes’, enter file name - will be saved in /data/ubcitm10/Sandra/ALVIN_ventricles)
			>>> (select ‘Yes’ for ‘Segment in native space?’)
	- outputs file ALVIN_native* in subjdir for each subject selected

(3) Register PDW
	* Register PDW to SPGRfa13 and apply to lesion masks, which are in PDW space
	> bash run_WCmaps_OPERA_DESPOT.bash SUB NUM WK 1
	- Calls TWC_ROISelection_OPERA_DESPOT.bash function LesionR
	- Steps:
		(i) Confirm all expected files and directories exist
		(ii) Register PDW to SPGRfa13 with FLIRT
		(iii) Apply registration matrix to lesion mask

(4) Matlab processing
	* Make initial TWC map: has B1+ correction (from DESPOT1-HIFI) and T2* correction, but no B1- correction
	> bash run_WCmaps_OPERA_DESPOT.bash SUB NUM WK 2
	- Calls run_invivo_WC_processing_general_OPERA_DESPOT.m in matlab
	- Steps:
		(i) Make T2*-corrected TWC map
			- Convert Mo to uncorrected PD by Mo=PD*exp(-TE/T2*)
			- Remove holes from ventricle mask & erode edges to prevent partial volume effects
			- Normalize PD map to mean PD in eroded ventricle mask and multiply by .99 (CSF is 99% water => internal standard method)
		(ii) Make tissue mask
			- Brain-extract and segment T1WPRE if not already done
			- Add WM & GM masks from segmentation and subtract dilated ventricle mask if not already done
			- Dilate CSF mask from segmentation and subtract from tissue mask
			- Subtract pathology mask from tissue mask
		(iii) Collect inputs for octave fitting
			- Puts the following in subjdir/WC_results/pPD_Biasfieldinputs.mat:
				- Initial guess for A & B fitting values
				- TWC map from step 4i
				- T1 map
				- tissue mask from step 4ii
				- slicemin & slicemax from Slicelims.txt or .mat
				- eroded ventricle mask
				- directory for ROIs
				- brain mask from step 4ii
	- Only parameter value in code is TE = 0.0036 sec (for SPGR)

(5) Register ROIs
	* Register ROIs for octave fitting from MNI152 standard space to subject space
	> bash run_WCmaps_OPERA_DESPOT.bash SUB NUM WK 3
	- Calls TWC_ROISelection_OPERA_DESPOT.bash function ROIselect
	- Default is to register SPGRfa13_ax to MNI brain and skull (not brain-extracted) as this seemed to be most effective. Can change which images to register by running “> bash run_WCmaps_OPERA_DESPOT.bash SUB NUM WK 3 ‘’ ‘’ ‘SUBJECT_REG_IMG’ BRAIN”
	- Steps:
		(i) Confirm all expected files and directories exist
		(ii) Register SPGRfa13 to MNI
			- Non-linear registration with fsl_reg (FLIRT + FNIRT)
			- Create inverse warp
		(iii) Process ROI masks
			- Apply inverse warp from step 5ii to ROI mask (warp to SPGRfa13 space)
			- Remove CSF by subtracting ventricle mask from step 2 and CSF mask from step 4ii and remove pathology with pathology mask from step 1
			- For WM ROIs, remove any tissue not in the WM mask (which may still leave deep GM => don’t do opposite to remove non-GM from GM ROIs because deep GM isn’t always in the GM mask)
			- Convert from NIfTI to .mat using nii2mat_ROI.m
			- Any ROI smaller than 50 voxels is discarded (not converted, so octave will ignore it) - cut-off is arbitrary (seemed like most ROIs were larger than 50 voxels)
			- Runs for each standard ROI in /data/chorus/ORCHESTRA/SCR1/KIMBERLEY/TWC_ROIs
			- Intermediate masks are saved in subjdir/ROIs/InProg
			- Final ROI masks are saved in subjdir/ROIs
			- Standard ROIs were made by saving atlas structures and then processing with /data/chorus/ORCHESTRA/SCR1/KIMBERLEY/scripts/TWC_autoROI/make_TWC_ROI_masks.bash
				- JHU White-Matter Tractography atlas: L/R ILF, SLF, CST
				- Juelich Histological atlas: callosal body
				- Harvard-Oxford Subcortical Structual atlas: L/R putamen, thalamus, caudate
	- *** ROIs SHOULD BE CHECKED VISUALLY TO CONFIRM THAT THEY ARE IN THE CORRECT TISSUE TYPE ***
		- Code to check ROIs in fslview is printed to the log file => copy/paste into terminal (then set base T1WPRE image to Grayscale and opacity/transparency 1 for best contrast, scroll through all slices)

(6) octave processing
	* Remove B1- inhomogeneity artifacts using Volz’ pseudo Proton Density (pPD) method
	- See Sandra’s instructions for TWC processing for an explanation of how it works, or read the paper by Volz et al, PubMed ID 22796988
	- octave code provided by Ralf Deichmann
	> bash run_WCmaps_OPERA_DESPOT.bash SUB NUM WK 4
	- Calls run_pPD_biasfield7it_kc.m in octave (only runs in octave, not matlab, because of the polyfit function for fitting bias field with a 10th order polynomial)
		- octave is installed (only) on amadeus
	- Uses inputs from step 4iii and ROIs from step 5
	- Outputs saved to subjdir/WC_results/pPD_Biasfieldoutputs_7iterations.mat, final TWC map also saved as subjdir/WC_results/WCmap.mat

(7) QC
	* Check TWC map outputs for any abnormalities or visually obvious systematic artefacts
	> matlab
		>> path(path,'/data/chorus/ORCHESTRA/RBIN/matlab/WC/')
		>> check_wc_maps('SUB',NUM,WK)
	- Check that values are primarily between 0 and 1 (at least in tissue; ok if some parts of ventricles are >1)
		- literature values have GM ~0.8, WM ~0.7
		- DESPOT1 TWC maps seem to generally be 0.05-0.1 lower than literature, at least for OPERA

(8) Redo maps, if necessary
	* Redo maps with different parameters (e.g. change matlab code for step 4, change registration images for step 5)
	> bash redo_WCmaps_OPERA_DESPOT.bash [OPTIONS] - run without arguments to see all options
	- Moves most recent TWC map & all associated files to a ‘backup’ version (W###_#)
	- Copies all files from most recent TWC map back to new W### and deletes any files that would prevent chosen processing steps from running properly
	- Re-runs chosen processing steps

(9) Stats
	* Convert to NIfTI and register to subject’s template space
	> sh reg2template.sh SUB NUM WK (STEPS)
	- STEPS=1 runs conversion, STEPS=2 runs registration, STEPS=12 runs both
	- Used ANTS registration for OPERA_DESPOT instead of FLIRT; implemented by Lisa Tang

	* Output mean TWC values in ROIs (general OPERA ones, not the ones from step 5) or lesions
	> bash getROIstats_KC.bash
	> matlab
		>> path(path,'/data/chorus/ORCHESTRA/SCR1/KIMBERLEY/scripts/TWC_autoROI/‘)
		>> GetLesionWCValues.m
	- Edit script to select which subjects/timepoints to run
	- ROI calculations are done in template space, lesion calculations are done in SPGR space



OTHER NOTES
	- More information in /data/ubcitm10/Sandra/WaterContentMapping_Instructions_updated.docx
	- /data/ubcitm10/ForWC/OPERA_DESPOT contains a directory for each subject (ORCH_CON_### or ORCH_OPE_###). Within each subject’s directory is a directory for each week they were scanned (e.g. W000, W024, …) - these directories are the ‘subjdir’ inputs for matlab and referred to above. Old versions are labelled W###_#;  history is below.
	- Full analysis (TWC map with T2* correction) done for all subjects/timepoints with all required images & maps (see history for list)
	- Errors in matlab often occur when there are too many files that match the search term - using redo_WCmaps_OPERA_DESPOT.bash should prevent this when reprocessing
	- Outputs from Kimberley’s TWC processing are saved in /data/chorus/ORCHESTRA/SCR1/KIMBERLEY/scripts/text_outputs/OPERA_DESPOT
	- Maximum T1 value allowed in DESPOT1-HIFI processing can be changed in /data/chorus/ORCHESTRA/SCR1/KIMBERLEY/scripts/TWC_autoROI/DESPOT1/despot1_single.c (lines 1037 & 1219)
	- Automated ROI selection has been implemented for OPERA GRASE, iCAMMS and CHUGAI TWC maps; DESPOT1 TWC mapping has not been implemented for any other data sets as of 7 Jun 2016.
	- TWC maps made with DESPOT and GRASE are not quantitatively comparable; neither are DESPOT with and without T2* correction



FINAL VERSIONS OF WC MAPS
- Final TWC map for the following subjects is T2*-corrected => copied to ORCHESTRA/MAPS/TWC & registered to template:
	- All time points:
		CON: 1 3 4 5 6 7 8 9 12 13 14 15 17 19 24(W048*) 27 28 29 31 33 34 37 38 39(W000*,W048*) 40 42(W000*,W048*) 44
		OPE: 19 20 21 22 25 26 33 37 38 39 41 43 46 51 52 53 58(W048**) 59 61 62
	- Some time points:
		CON: 2(W000) 10(W000) 11(W000,W048) 16(W000) 20(W000) 21(W000) 22(W048,W096) 25(W000,W048) 26(W000) 32(W000) 35(W000) 36(W000,W048) 41(W000) 43(W000*,W048*) 45(W000,W048) 46(W000,W048) 47(W000*,W048*)
		OPE all but baseline (W024,W048,W096): 2 4 7 9 15 16 18 36
		OPE: 6(W024,W048) 10(W024,W096) 14(W048,W096) 23(W000) 24(W096) 28(W024,W048) 32(W000,W024,W048) 35(W000,W024) 45(W000,W024,W048) 60(W000)
	* - values seem high or low in whole brain or WM => QC=?
	** - anterior R cortex blurry - partial volume effect? => QC=?

- Final TWC map for the following subjects is NOT T2*-corrected because SWI missing (TWC map not checked, not copied to ORCHESTRA/MAPS/TWC or registered to template):
	- All existing time points:
		OPE: 1 8 11 13 17 27 29 30 34 40 42 44 47 48 49 50 54 56 57 63 64
	- Baseline only:
		OPE: 2 4 7 9 10 15 16 18 55
	- Some time points:
		OPE: 6(W096) 14(W000,W024) 23(W024,W048,W096) 28(W000,W096) 32(W096) 35(W048,W096)

- No TWC map because of octave problem: CON 22 W000, OPE 10 W048, OPE 45 W096
- No TWC map because no lesion mask (also no SWI): OPE 3 W048 & W096, OPE 12 W000, OPE 29 W000, OPE 65 W000
	


HISTORICAL VERSIONS OF WC MAPS
Documentation of parameters used for WC maps in W###_# subjdirs
- all maps redone at least once to add T2*-correction if available, remove reliance on CSF fraction map (use sum ventricle mask instead) and use tissue mask without pathology -> final version has all of this, first version (_0) has none of this
- see excel sheet /data/ubcitm10/ForWC/OPERA_DESPOT/WC_OPERA_repeats.xlsx for parameters used for intervening versions



ADAPTING SCRIPTS TO OTHER STUDIES (points in script to be edited)
- cp_OPERA_DESPOT.bash:
	- Set up: file locations and naming convention
	- Processing: NUM and WK at beginnings of ‘for’ loops, if different padding required
	- Processing: switch location of DESPOT files and whether they are named using DESPOT or mcDESPOT conventions, as necessary 	- lines to change marked with ’#’ at beginning of line (not indented)

- /data/workgroup/matlab/spm8/spm and /data/ubcitm10/Sandra/ALVIN_ventricles/ALVIN_v1p06.m:
	- no modifications needed

- run_WCmaps_OPERA_DESPOT.bash
	- search for “ # change for other data sets”
	- step 1: Log file name and location
	- step 2: TWC_ROISelection script name
	- step 3: subjdir format and script name for matlab and octave code

- TWC_ROISelection_OPERA_DESPOT.bash
	- LesionR, step 1: NUM (if different padding), NAME (naming convention), WC_DIR (general input/output file location), LESION (original lesion mask file name and location)
	- ROISelect, step 1: NUM (if different padding), NAME (naming convention), WC_DIR (general input/output file location)
	- ROISelect, step 3: minimum ROI size threshold in nii2mat_ROI function (3rd variable; number of voxels that constitutes ‘too small’ may depend on resolution of TWC map)

- run_invivo_WC_processing_general_OPERA_DESPOT.m
	- search for “% change for other data sets”
	- check inputs: abnormal tissue mask (registered pathology mask), TE (if not 0.0036 sec)
	- step 2: T1file (naming convention for T1-weighted image)

- nii2mat_ROI.m
	- no modifications needed

- run_pPD_biasfield7it_kc.m
	- no modifications needed

- check_wc_maps.m
	- default values for SUB, NUM and WEEK, and padding (if necessary)
	- subjdir (location of WC_results directory)

- (optional) redo_WCmaps_OPERA_DESPOT.bash
	- search for “ # change for other data sets”
	- step 2: WKDIR (path to original directory containing that timepoint’s data) and name of TWC map when converted to .nii(.gz)
	- step 3: LOGFILE (path to log file) and run_WCmaps_….bash script name

- (optional) reg2template.sh
	- first few lines of each step
	- step 1: LOGFILE (path to log file)
	- step 2: file naming conventions: WCNII, WCMAT and SPGR
	- step 3: file naming conventions: TEMPDIR, NAME, WCNII, WC2TEMPLATE, REF, MATRIX

- (optional) getROIstats_KC.bash
	- OUTDIR and MASKDIR at top of script
	- which subjects and timepoints
	- all input file names: INPUT map and masks for each ROI (and maybe also ROI names)

- (optional) GetLesionWCValues.m
	- all file names - WCDIR and NAME at top, LESION in first line of try and catch blocks, and final gzip line





