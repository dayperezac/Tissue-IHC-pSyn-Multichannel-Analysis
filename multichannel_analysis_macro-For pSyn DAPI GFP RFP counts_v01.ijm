//This macro quantifies pSyn area percentage and counts for GFP and RFP channels
//pSyn is target channel
//This includes changes from previous versions to prevent crash when values are zero
//Update 2026/07/010

// ============================================================
// DIALOG: all settings upfront
// ============================================================
Dialog.create("Image Analysis Settings");
Dialog.addString("Experiment name:", "");
Dialog.addNumber("Number of channels in images:", 4);

Dialog.addMessage("--- Target Channel ---");
Dialog.addNumber("Target channel (e.g. 2 for C2):", 2);
Dialog.addNumber("Target lower threshold:", 0);
Dialog.addNumber("Target upper threshold:", 65535);

Dialog.addMessage("--- DAPI Channel ---");
Dialog.addNumber("DAPI channel (e.g. 1 for C1):", 1);

Dialog.addMessage("--- GFPretro Channel ---");
Dialog.addNumber("GFPretro channel (e.g. 3 for C3):", 3);
Dialog.addNumber("GFPretro lower threshold:", 0);
Dialog.addNumber("GFPretro upper threshold:", 65535);

Dialog.addMessage("--- RFP Channel ---");
Dialog.addNumber("RFP channel (e.g. 4 for C4):", 4);
Dialog.addNumber("RFP lower threshold:", 0);
Dialog.addNumber("RFP upper threshold:", 65535);

Dialog.show();

experimentName = Dialog.getString();
numChannels    = Dialog.getNumber();

targetChannel  = Dialog.getNumber();
lowerThresh    = Dialog.getNumber();
upperThresh    = Dialog.getNumber();

dapiChannel    = Dialog.getNumber();

gfpChannel     = Dialog.getNumber();
gfpLower       = Dialog.getNumber();
gfpUpper       = Dialog.getNumber();

rfpChannel     = Dialog.getNumber();
rfpLower       = Dialog.getNumber();
rfpUpper       = Dialog.getNumber();

// ============================================================
// FOLDERS
// ============================================================
imagesFolder = getDirectory("Choose directory containing images");
resultsFolder = getDirectory("Choose directory to save results");
list = getFileList(imagesFolder);

masksFolder  = resultsFolder + "Masks"    + File.separator;
targetFolder = masksFolder   + "Target"   + File.separator;
gfpFolder    = masksFolder   + "GFPretro" + File.separator;
rfpFolder    = masksFolder   + "RFP"      + File.separator;

File.makeDirectory(resultsFolder);
File.makeDirectory(masksFolder);
File.makeDirectory(targetFolder);
File.makeDirectory(gfpFolder);
File.makeDirectory(rfpFolder);

// ============================================================
// RESULTS TABLE
// ============================================================
run("Clear Results");
Table.create("My Results");

// ============================================================
// MAIN LOOP
// ============================================================
for (i = 0; i < list.length; i++) {
    showProgress(i+1, list.length);

    open(imagesFolder + list[i]);
    filename = list[i];
    name     = File.nameWithoutExtension;
    rawName  = getTitle();

    // Clear Results table each iteration to prevent accumulation
    run("Clear Results");

    // Default values — ensures a row is always written even if a channel
    // produces no signal or no particles
    targetArea         = 0;
    targetMean         = 0;
    targetMin          = 0;
    targetRawIntDen    = 0;
    targetIntDen       = 0;
    targetAreaFraction = 0;
    gfpCount           = 0;
    rfpCount           = 0;

    // ----------------------------------------------------------
    // Split channels — keep target, DAPI, GFP, RFP; close the rest
    // ----------------------------------------------------------
    run("Split Channels");
    for (c = 1; c <= numChannels; c++) {
        if (c != targetChannel && c != dapiChannel && c != gfpChannel && c != rfpChannel) {
            if (isOpen("C" + c + "-" + rawName)) {
                selectWindow("C" + c + "-" + rawName);
                close();
            }
        }
    }

    // ----------------------------------------------------------
    // TARGET CHANNEL — intensity measurements + mask
    // ----------------------------------------------------------
    selectWindow("C" + targetChannel + "-" + rawName);
    setThreshold(lowerThresh, upperThresh, "raw");
    run("Set Measurements...", "area mean min integrated area_fraction limit redirect=None decimal=3");
    run("Measure");

    targetResultRow = 0; // always 0 — Results table cleared at start of each iteration

    // NaN-safety: if no pixels fell in the threshold range these can be NaN
    v = getResult("Area", targetResultRow);
    if (!isNaN(v)) targetArea = v;

    v = getResult("Mean", targetResultRow);
    if (!isNaN(v)) targetMean = v;

    v = getResult("Min", targetResultRow);
    if (!isNaN(v)) targetMin = v;

    v = getResult("RawIntDen", targetResultRow);
    if (!isNaN(v)) targetRawIntDen = v;

    v = getResult("IntDen", targetResultRow);
    if (!isNaN(v)) targetIntDen = v;

    v = getResult("%Area", targetResultRow);
    if (!isNaN(v)) targetAreaFraction = v;

    setOption("BlackBackground", false);
    run("Convert to Mask");
    saveAs("TIFF", targetFolder + name + "_Target_MASK_t" + lowerThresh + "-" + upperThresh + ".tif");
    close(); // target mask

    // ----------------------------------------------------------
    // DAPI CHANNEL — threshold → watershed → particle analysis
    // ----------------------------------------------------------
    selectWindow("C" + dapiChannel + "-" + rawName);
    close(); // dapiMaskPath window

    // ----------------------------------------------------------
    // GFPretro CHANNEL — threshold → erode → watershed → particle
    // ----------------------------------------------------------
    selectWindow("C" + gfpChannel + "-" + rawName);
    run("Grays");
    setThreshold(gfpLower, gfpUpper, "raw");
    setOption("BlackBackground", false);
    run("Convert to Mask");
    run("Erode");
    run("Watershed");

    gfpMaskPath = gfpFolder + name + "_GFPretro_MASK_t" + gfpLower + "-" + gfpUpper + ".tif";
    saveAs("TIFF", gfpMaskPath);
    close(); // gfp mask

    roiManager("reset");
    open(gfpMaskPath);
    run("Analyze Particles...", "size=50-500 circularity=0.20-1.00 show=[Overlay Masks] display exclude add");
    gfpCount = roiManager("count");

    run("Flatten");
    saveAs("TIFF", gfpFolder + name + "_GFPretro_MASK_overlay_t" + gfpLower + "-" + gfpUpper + ".tif");
    close(); // flattened overlay

    // Guard: only save ROI zip if particles were found
    if (gfpCount > 0) {
        roiManager("Save", gfpFolder + name + "_GFPretro_ROIs.zip");
    } else {
        print(name + ": no GFPretro particles found — storing count as 0, no ROI file saved");
    }
    roiManager("reset");
    close(); // gfpMaskPath window

    // ----------------------------------------------------------
    // RFP CHANNEL — threshold → erode → watershed → particle
    // ----------------------------------------------------------
    selectWindow("C" + rfpChannel + "-" + rawName);
    run("Grays");
    setThreshold(rfpLower, rfpUpper, "raw");
    setOption("BlackBackground", false);
    run("Convert to Mask");
    run("Erode");
    run("Watershed");

    rfpMaskPath = rfpFolder + name + "_RFP_MASK_t" + rfpLower + "-" + rfpUpper + ".tif";
    saveAs("TIFF", rfpMaskPath);
    close(); // rfp mask

    roiManager("reset");
    open(rfpMaskPath);
    run("Analyze Particles...", "size=50-500 circularity=0.20-1.00 show=[Overlay Masks] display exclude add");
    rfpCount = roiManager("count");

    run("Flatten");
    saveAs("TIFF", rfpFolder + name + "_RFP_MASK_overlay_t" + rfpLower + "-" + rfpUpper + ".tif");
    close(); // flattened overlay

    // Guard: only save ROI zip if particles were found
    if (rfpCount > 0) {
        roiManager("Save", rfpFolder + name + "_RFP_ROIs.zip");
    } else {
        print(name + ": no RFP particles found — storing count as 0, no ROI file saved");
    }
    roiManager("reset");
    close(); // rfpMaskPath window

    // ----------------------------------------------------------
    // WRITE ROW TO CUSTOM RESULTS TABLE
    // ----------------------------------------------------------
    row = Table.size("My Results");
    Table.set("Filename",       row, name,               "My Results");
    Table.set("Area",           row, targetArea,          "My Results");
    Table.set("Mean",           row, targetMean,          "My Results");
    Table.set("Min",            row, targetMin,           "My Results");
    Table.set("RawIntDen",      row, targetRawIntDen,     "My Results");
    Table.set("IntDen",         row, targetIntDen,        "My Results");
    Table.set("Area_Fraction",  row, targetAreaFraction,  "My Results");
    Table.set("GFPretro_Count", row, gfpCount,            "My Results");
    Table.set("RFP_Count",      row, rfpCount,            "My Results");
    Table.update("My Results");

    // Safety net — close any leftover windows, free memory
    close("*");
    run("Collect Garbage");
}

// ============================================================
// SAVE RESULTS TABLE
// ============================================================
selectWindow("My Results");
saveAs("Results", resultsFolder + experimentName + "_" + getDateString() + "_Analysis_Results.csv");

// ============================================================
// HELPER: date string YYYYMMDD
// ============================================================
function getDateString() {
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    return "" + year + IJ.pad(month+1, 2) + IJ.pad(dayOfMonth, 2);
}