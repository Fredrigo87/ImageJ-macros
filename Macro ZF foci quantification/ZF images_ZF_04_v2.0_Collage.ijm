requires("1.52p");
print("------- Starting ZF analisys macro step 4");

//Update 2.0 - 11.04.2023
//Split macro in multiple sub-macros, to be run independently
//ZF_1 - macro to generate input files and prepare output folders
//ZF_2 - macro to prepare files (check orientation and split channels)
//ZF_3 - macro to quantify signal and save quantified files
//ZF_4 - macro to generate collage
//Workaround for Windows Creator Update that causes freezing of ImageJ when using "Import image sequence" command.
//This disables the use of JFile chooser to import sequences
//CAUTION: this overwrites any other custom options!
//run("Input/Output...", "jpeg=85 gif=-1 file=.csv use copy_row save_column save_row");

/// Setting up the variables
//gFoldersArray = newArray("Analysis\\", "Collage\\", "Merged\\", "Masks\\", "Masks\\Cropped\\", "Masks\\Quantified\\");
gFoldersArray = newArray("Analysis\\", "RotatedStacks\\", "Cropped\\", "Masks\\", "Quantified\\", "AdjThr\\", "Collage\\", "Overlay\\", "allCh\\", "noBF\\");
gExt = "ome.tif";
gImgPath = getDirectory("Choose the root directory with the images to be analyzed");
stackImgPath = gImgPath+gFoldersArray[0]+gFoldersArray[1];
gOutputDir = gImgPath+gFoldersArray[0];
if (File.exists(gOutputDir+"ZF_01_Input.csv")==true) {
	print("File list found, opening...");
	fileTable = Table.open(gOutputDir+"ZF_01_Input.csv");
	} else {
		exit("File list not found");
}
gInputList_2 = Table.getColumn("Image_File");
close("ZF_01_Input.csv");
gStacks = newArray("RDstack", "GRstack", "BLstack", "BFstack");
Table.open(gOutputDir+"ZF_02_Var.csv");
macroVariables = Table.getColumn("Var_ZF_02");
close("ZF_02_Var.csv");
nCh = macroVariables[3]; //this is now the amount of channels, considering BF 1 channel instead of 3 separate ones
chVessels = macroVariables[1];
chQuant = macroVariables[2]; //GRstack, RDstack etc
chStack = newArray(nCh);
for (i=0;i<nCh;i++) {
	j=i+4;
	chStack[i] = macroVariables[j];
}



////////////////////
setBatchMode("hide");/// setbatchmode setting to lower memory usage
call("java.lang.System.gc");//clears some extra memory
selectWindow("BFstack");
imageCalculator("Add create stack", "BFstack","RDstack");
rename("partOverlay");
imageCalculator("Add create stack", "partOverlay","GRstack");
rename("OVstack");
///duplicate stack for fluorescence quantification
// stack title: "FluoQuant"
selectWindow(chQuant);
run("Duplicate...", "title=FluoQuant duplicate");

///generate stacks for collage
selectWindow("GRstack");
run("RGB Color", "slices");
run("Duplicate...", "title=GRstackRGB duplicate");
run("Combine...", "stack1=GRstack stack2=BFstack");
rename("partTop");
selectWindow("RDstack");
run("RGB Color", "slices");
imageCalculator("Add create stack", "GRstackRGB", "RDstack");
rename("MergeStack");
run("Combine...", "stack1=RDstack stack2=OVstack");
rename("partBottom");
run("Combine...", "stack1=partTop stack2=partBottom combine");
rename("collageStack");
m=nSlices;
labelsArray=newArray(m);
for (i=0; i<m; i++) {
	j=i+1;
	selectWindow("partOverlay");
	setSlice(j);
	labelsArray[i]=substring(getMetadata("Label"), 0, indexOf(getMetadata("Label"), "."));
	print(labelsArray[i]);
	label="Collage_"+labelsArray[i];
	selectWindow("collageStack");
	setSlice(j);
	setMetadata("Label", label);
	labelRD="Raw_"+labelsArray[i];
	selectWindow("FluoQuant");
	setSlice(j);
	setMetadata("Label", labelRD);
}

selectWindow("collageStack");
run("Image Sequence... ", "format=JPEG use save=["+gOutputDir+gFoldersArray[1]+"]");
print(gOutputDir+gFoldersArray[1]);
close("collageStack");
close("partOverlay");
selectWindow("MergeStack");
run("Image Sequence... ", "format=JPEG use save=["+gOutputDir+gFoldersArray[2]+"]");
close("MergeStack");
selectWindow("FluoQuant");
run("Image Sequence... ", "format=TIFF use save=["+gOutputDir+gFoldersArray[3]+"]");
close("GRstackRGB");
call("java.lang.System.gc");//clears some extra memory
setBatchMode("exit and display");
