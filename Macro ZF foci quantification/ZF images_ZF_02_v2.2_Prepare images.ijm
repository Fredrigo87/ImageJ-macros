requires("1.52p");
print("------- Starting ZF analisys macro step 2");
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

//closing all windows to avoid interferences
run("Close All");
Dialog.createNonBlocking("Closing images and log");
	Dialog.addMessage("Closing all images and Log window - save log now if required");
Dialog.show();
close("Log");
close("*.csv");

/// Setting up the variables
//gFoldersArray = newArray("Analysis\\", "Collage\\", "Merged\\", "Masks\\", "Masks\\Cropped\\", "Masks\\Quantified\\");
p = File.separator;
	gFoldersArray = newArray("Analysis"+p, "RotatedStacks"+p, "Cropped"+p, "Masks"+p, "Quantified"+p, "AdjThr"+p, "Collage"+p, "Overlay"+p, "allCh"+p, "noBF"+p);
gExt = "ome.tif";
gImgPath = getDirectory("Choose the root directory with the images to be analyzed");

//COMPLETE IT, CONTINUE
//testFolder=Table.open(gOutputDir+"ZF_01_Folders.csv")

gOutputDir = gImgPath+gFoldersArray[0];
if (File.exists(gOutputDir+"ZF_01_Input.csv")==true) {
	print("File list found, opening...");
	fileTable = Table.open(gOutputDir+"ZF_01_Input.csv");
	} else {
		exit("File list not found");
}
gInputList_2 = Table.getColumn("Image_File");
gStacks = newArray("RDstack", "GRstack", "BLstack", "BFstack");
radioLabels=newArray("Top-left", "Bottom-right", "Top-right", "Correct position");

// ask the user for further info: total channels, channels to quantify, channels order
chLabels = newArray("R-G-BF", "R-G-B-BF", "R-B-BF");
chLabelQuant = newArray("R", "G", "B");
Dialog.createNonBlocking("Channels");
	Dialog.addMessage("Indicate in what order the channels were acquired.");
	Dialog.addRadioButtonGroup("Ch order:", chLabels, 1, 3, "R-G-BF");
	Dialog.addRadioButtonGroup("Channel to quantify: ", chLabelQuant, 1, 3, "G");
	Dialog.addRadioButtonGroup("Channel with vessels: ", chLabelQuant, 1, 3, "R");
Dialog.show();
chOrder = Dialog.getRadioButton();
chQuant = Dialog.getRadioButton();
chRotate = Dialog.getRadioButton();
print(chOrder);
print(chQuant);

//Set variables with the right order of channels and right amount of channels
if (chOrder == chLabels[0]) {
	nCh = 5;
	chStack = newArray(gStacks[0], gStacks[1], gStacks[3]);
}
if (chOrder == chLabels[1]) {
	nCh = 6;
	chStack = newArray(gStacks[0], gStacks[1], gStacks[2], gStacks[3]);
}
if (chOrder == chLabels[2]) {
	nCh = 5;
	chStack = newArray(gStacks[0], gStacks[2], gStacks[3]);
}

//setting the stack to use for rotating the images
for (i=0;i<3;i++) {
	if (chRotate == chLabelQuant[i]) {
		chRotate = gStacks[i];
	}
}

//setting the stack to use to quantify
for (i=0;i<3;i++) {
	if (chQuant == chLabelQuant[i]) {
	chQuant = gStacks[i];
	}
}

//saving variables
saveVariables();

//open image sequence as stack
run("Image Sequence...", "open=["+gImgPath+"] sort");
rename("ORGstack");
n=(nSlices/nCh);
//generate one hyperstack per each image (5 channels: Red, Green, BF_green, BF_blue, BF_red)
run("Stack to Hyperstack...", "order=xyczt(default) channels="+nCh+" slices="+n+" frames=1 display=Color");


//generate one stack per each fluorescence channel (Red, Green, Blue)
//First channel is assumed to always be RED
for (i=0;i<nCh-3;i++) {
	j=i+1;
	selectWindow("ORGstack");
	run("Make Substack...", "channels="+j+" slices=1-"+n+"");
	rename(gStacks[i]); //GRstack
}

//remove fluo channels from original stack - this leaves the BF stack
j = nCh;
for (i=0;i<nCh-3;i++) {
	selectWindow("ORGstack");
	run("Slice Remover", "first=1 last="+nSlices+" increment="+j+"");
	j--;
}

//Identify BF stack
selectWindow("ORGstack");
run("Stack Splitter", "number="+n+"");
//generate BF images with correct channels, with labels --> this is overwritten, CHECK
for (i=0; i<n; i++) {
	j=i+1;
	if (j<10) {
		windowName="stk_000"+j+"_ORGstack";
		} else if (j>=10 &&j<100) {
			windowName="stk_00"+j+"_ORGstack";
			} else if (j>=100 && j<1000) {
				windowName="stk_0"+j+"_ORGstack";
				} else {
					windowName="stk_"+j+"_ORGstack";
	}
	selectWindow(windowName);
	label=getMetadata("Label");
	Stack.swap(1, 3);
	Stack.swap(1, 2);
	run("Stack to RGB");
	setMetadata("Label", label);
	if (i==0) {
		rename(gStacks[3]); //BFstack
		print("Renamed initial BFfile");
		} else {
		print("Concatenating BFfile "+j+" to BFstack");
		run("Concatenate...", "  title=BFstack image1=[BFstack] image2=["+windowName+" (RGB)]");
	}
}
close("*ORGstack");
//Rotate images
//radioLabels=newArray("Top-left", "Bottom-right", "Top-right", "Correct position");
selectWindow(chRotate);
nAdj=getSliceNumber();
stopTransform=false;
while (stopTransform==false) {
	Dialog.createNonBlocking("Scroll to the next image to rotate");
		Dialog.addRadioButtonGroup("Tail position: ", radioLabels, 4, 1, "Correct position");
		Dialog.addCheckbox("Finished", false);
	Dialog.show();
	transf=Dialog.getRadioButton();
	finish=Dialog.getCheckbox();
	if (finish==true) {
		stopTransform=true;
		} else {
			nAdj=getSliceNumber();
			flipImg(nCh, nAdj, chStack, transf);
			
	}
	
}
//Saving stacks
//using folder \Analysis\Stacks
//Table.open(gOutputDir+"ZF_01_Input.csv");
fileTable=Table.getColumn("Image_File");
saveCheckStacks(fileTable);

//save the log file for step 2
selectWindow("Log"); 
saveAs("Text", gOutputDir+"Log_macro_step_2.txt"); 

showMessage("Step 2 completed");


/////////////////////////// FUNCTIONS/////

function flipImg (nCh, nAdj, chStack, transf) {
	for (k=0;k<nCh-2;k++){
		selectWindow(chStack[k]);
		setSlice(nAdj);
		//print(k);
		if (transf==radioLabels[1]) {
			run("Flip Horizontally", "slice");
			//print(nAdj+": "+radioLabels[1]);
			} else if (transf==radioLabels[0]) {
				run("Flip Vertically", "slice");
				//print(nAdj+": "+radioLabels[0]);
				} else if (transf==radioLabels[2]) {
					run("Flip Vertically", "slice");
					run("Flip Horizontally", "slice");
					//print(nAdj+": "+radioLabels[2]);
		}
	}
	selectWindow(chRotate);
	if (nAdj<nSlices) {
		nAdj=nAdj+1;
	}
	setSlice(nAdj);
	close("Scroll to the next image to rotate");	
}

function saveCheckStacks(fileTable) {
	//checking that names stored by the previous macro match the labels in the stack
	for (k=0;k<nCh-2;k++){
		selectWindow(chStack[k]);
		for (i=0;i<nSlices;i++) {
			j=i+1;
			setSlice(j);
			//fileTable[i];
			label=getMetadata("Label");
			label=substring(label, 0, lengthOf(label)-2);
			if (fileTable[i] != label) {
				print("Error with file '"+label+"'");
				print("File label: "+label);
				print("Table label: "+fileTable[i]);
				} else {
					label=substring(fileTable[i], 0, lengthOf(label)-8); //removing the extension for saving the label
					setMetadata("Label", label);
					print("checking file '"+label+"'");
			}
		}
		//saving the stacks
		selectWindow(chStack[k]);
		saveAs("Tiff", gOutputDir+gFoldersArray[1]+chStack[k]);
		print("Saving stack "+chStack[k]);
		rename(chStack[k]);
	}
}

function saveVariables() {
	fileOutputDir=File.open(gOutputDir+"ZF_02_Var.csv");
	print(fileOutputDir, "Var_ZF_02");
	print(fileOutputDir, nCh);
	print(fileOutputDir, chRotate);
	print(fileOutputDir, chQuant);
	print(fileOutputDir, chStack.length);
	for (i=0;i<chStack.length;i++) {
		print(fileOutputDir, chStack[i]);
	}
	File.close(fileOutputDir);
}
