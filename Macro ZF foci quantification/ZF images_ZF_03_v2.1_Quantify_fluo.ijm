requires("1.52p");
print("------- Starting ZF analisys macro step 3");
List.setCommands;
if (List.get("Read and Write Excel")!="") {
	print("Read and Write Excel plugin detected.");
	} else {
		exit("Plugin 'Read and Write Excel' is missing. Install it before resuming the analysis");
}
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

//24.04.23 replaced "\\" with File.separator to increase cross-OS compatibility

/// Setting up the variables
//gFoldersArray = newArray("Analysis\\", "Collage\\", "Merged\\", "Masks\\", "Masks\\Cropped\\", "Masks\\Quantified\\");
p = File.separator;
gFoldersArray = newArray("Analysis"+p, "RotatedStacks"+p, "Cropped"+p, "Masks"+p, "Quantified"+p, "AdjThr"+p, "Collage"+p, "Overlay"+p, "allCh"+p, "noBF"+p);
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

ThrLow=20;
ThrUpp=255;

//avoid closing windows, to save some processing time if stacks are already open
//closing all windows to avoid interferences
//run("Close All");
//Dialog.createNonBlocking("Closing images and log");
	//Dialog.addMessage("Closing all images and Log window - save log now if required");
//Dialog.show();
//close("Log");
//close("*.csv");

//open stacks
for (i=0;i<nCh;i++) {
	if (isOpen(chStack[i])!=1) {
		print("Stack '"+chStack[i]+"' is not open. Opening it...");
		print("Opening "+stackImgPath+chStack[i]+".tif");
		//run("Image Sequence...", "open=["+stackImgPath+"] filter="+chStack[i]+" sort");
		open(stackImgPath+chStack[i]+".tif");
		rename(chStack[i]);
	}
}
n=(nSlices/nCh);
selectWindow(chQuant);
setSlice(1);

//Setting the threshold for quantification
setThreshold(ThrLow, ThrUpp);
run("Threshold...");
waitForUser("Select a threshold that can fit all open images, then click 'Set' and confirm. Press 'Ok' in THIS window when done.");
getThreshold(ThrLow, ThrUpp);
print("retrieved thresholds: "+ThrLow+", "+ThrUpp);
close("Threshold");
selectWindow(chQuant);
run("Duplicate...", "duplicate");
rename(chQuant+"_Cropped");

//Generate or load the ROI
Dialog.createNonBlocking("ROI generation");
	Dialog.addMessage("Draw a loose ROI around the tail. Ensure that the size and shape of the ROI fit all the images. Press 'OK' when ready to measure");
	Dialog.addCheckbox("Is the ROI already available? Check and press 'OK'", false);
Dialog.show();
ROIexists = Dialog.getCheckbox();
if (ROIexists==true) {
	selectWindow(chQuant+"_Cropped");
	roiManager("Open", ""+gOutputDir+"TailFluo.roi");
	roiManager("Select", 0);
	} else {
		roiManager("Add");
		roiManager("Select", 0);
		roiManager("Rename", "TailFluo");
		roiManager("Save", ""+gOutputDir+"TailFluo.roi");
}
close("ROI Manager");

//Measure ROI-specific fluorescence
run("Clear Results");
run("Set Measurements...", "area mean min area_fraction limit redirect=None decimal=3");
selectWindow(chQuant+"_Cropped");
setThreshold(ThrLow, ThrUpp);
//selectWindow(chQuant);
label="";
setForegroundColor(255, 255, 255);
setBackgroundColor(0, 0, 0);
for (i=0; i<nSlices; i++) {
	j=i+1;
	setSlice(j);
	waitForUser("Move the ROI to the correct position. \nPress any ROI selection button before moving the ROI.");
	//////////////////////////////////////////////////////////////////////// here
	// added on 16.10.22 to clear the outside of the ROI
	//run("Duplicate...", "use");
	run("Clear Outside", "slice");
	//run("Make Inverse"); //removed in version 2.0, 16.04.23
	//run("Invert", "slice");
	//run("Make Inverse");
	// end of addition
	run("Measure");
	//run("Select None");
	label="Cropped_"+getMetadata("Label");
	print(label);
	setMetadata("Label", label);
	//if (i==0) {
		//rename("CropStack"); ////////////new name for stack to be quantified
		//rename(chQuant+"_Cropped");
		//} else {
		//print("Concatenating cropped images");
		//image2=getTitle();
		//run("Concatenate...", "  title=CropStack image1=[CropStack] image2=["+image2+"]");
		//rename(chQuant+"_Cropped");
	//}
}
run("Read and Write Excel", "file=["+gOutputDir+"Detailed_Analysis.xlsx] sheet=TailFluo dataset_label=[Thresholded Fluo]");
//run("Clear Results");
close("Results");

//save cropped stack
selectWindow(chQuant+"_Cropped");
run("Hide Overlay");
saveAs("Tiff", gOutputDir+gFoldersArray[2]+chQuant+"_Cropped");
print("Saving cropped stack "+chQuant);
rename(chQuant+"_Cropped");
		
//generating masks for particle quantification
preprocessStack();

//Particles quantification
particleQuant(gOutputDir);
call("java.lang.System.gc");//clears some extra memory
print("Analysis terminated");

selectWindow("Log"); 
saveAs("Text", gOutputDir+"Log_macro_step_3.txt"); 

showMessage("Step 3 completed");

//////////////////////////////////// FUNCTIONS
function preprocessStack() {
	selectWindow(chQuant+"_Cropped");
	run("Select None");
	//setBatchMode(true);
	setSlice(1);
	//run("Gaussian Blur...", "sigma=1 stack");
	print("Using previously set threshold values: "+ThrLow+", "+ThrUpp+".");
	setThreshold(ThrLow, ThrUpp);
	//setOption("BlackBackground", false);
	run("Convert to Mask", "method=Default background=Default");
	//run("Erode", "stack");
	//run("Dilate", "stack");
	run("Open", "stack");
	run("Close-", "stack");
	run("Invert", "stack");
	run("Watershed", "stack");
	run("Invert", "stack");
	//selectWindow("Log"); 
	//saveAs("Text", output_dir+"Thr-list_Red fluorescence.txt"); 
	//setBatchMode(false);
	saveAs("Tiff", gOutputDir+gFoldersArray[3]+chQuant+"_Masks");
	rename(chQuant+"_Masks");
}

function particleQuant(output_dir) {
	run("Set Measurements...", "area stack display redirect=None decimal=2");
	partCheck = false;
	varPart = 80;
	//run("Invert", "stack");
	//Check particle size
	while (partCheck==false) {
		run("Analyze Particles...", "size="+varPart+"-Infinity show=Overlay exclude clear summarize stack");
		Dialog.createNonBlocking("Particle Quantification");
			Dialog.addMessage("Scroll the stack and check the particle size is correct");
			Dialog.addNumber("Particle size to use: ", varPart);
			Dialog.addCheckbox("Parameter optimized?", false);
		Dialog.show();
		varPart= Dialog.getNumber();
		partCheck = Dialog.getCheckbox();
		close("Summary of "+chQuant+"_Masks");
	}
	run("Analyze Particles...", "size="+varPart+"-Infinity show=Overlay display exclude clear summarize stack");
	run("Read and Write Excel", "file=["+output_dir+"Detailed_Analysis.xlsx] sheet=PartQuant dataset_label=[Slide "+j+"]");
	run("Clear Results");
	close("Results");
	run("Labels...", "color=magenta font=24 show");
	//run("Invert", "stack");
	selectWindow(chQuant+"_Masks");
	rename(chQuant+"_Quantified");
	run("Flatten", "stack");
	saveAs("Tiff", gOutputDir+gFoldersArray[3]+gFoldersArray[4]+chQuant+"_Quant");
	rename(chQuant+"_Quantified");
	//run("Image Sequence... ", "format=JPEG use save=["+gOutputDir+gFoldersArray[5]+"]");
	Table.rename("Summary of "+chQuant+"_Masks", "Results");
	run("Read and Write Excel", "file=["+output_dir+"Detailed_Analysis.xlsx] sheet=Summary dataset_label=[Cropped Tail Fluo]");
	close("Summary of "+chQuant+"_Masks");
	close("Results");
}