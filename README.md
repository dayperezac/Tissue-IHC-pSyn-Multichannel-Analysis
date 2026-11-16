# Tissue-IHC-pSyn-Multichannel-Analysis
This macro is used to quantify pSyn and positive neurons (Ex. GFP+, RFP+, DAPI) from 20X images. 
---README---
Image J macro

Macro Name:
multichannel_analysis_macro-For pSyn DAPI GFP RFP counts_v01

Image format
.tif

Image type:
20X Multichannel Z- projections. 

Macro Description. 
This macro is used to quantify pSyn and positive neurons (Ex. GFP+, RFP+, DAPI) from 20X images. 

User input
Image Analysis Settings
	-Experiment name
	-Number of Channels in the Image
	-Indicate target channel (pSyn), and other marker channels with their respective threshold to detect positive signals.

Note: The current detection for cells is 50-500 um size with a circularity of 0.20-1.00. Depending of cell type this parameters should be adjusted.  


Output
Analysis will generate verification image masks for all channels, ROIs folders, and an analysis result CSV. 


