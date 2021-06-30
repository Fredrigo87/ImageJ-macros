requires("1.52p");
//Workaround for Windows Creator Update that causes freezing of ImageJ when using "Import image sequence" command.
//This disables the use of JFile chooser to import sequences
//CAUTION: this overwrites any other custom options!
//run("Input/Output...", "jpeg=85 gif=-1 file=.csv use copy_row save_column save_row");
	//FUNCTION: get input file list
	print("Starting inputListCheck function...");
	inputListCheck_result=inputListCheck();
	gInputList_1=Array.slice(inputListCheck_result,1,inputListCheck_result.length);
	gImgPath=inputListCheck_result[0];
	print("Function inputListCheck finished.");

	//FUNCTION: generate a clean input list (only image files)
	//input: gInputList_1[#], gExt
	//output: j, vFileList[#]
	gExt="ome.tif";
	print("Starting function generateInput...");
	generateInput_result=generateInput(gInputList_1, gExt);
	gInputList_2=Array.slice(generateInput_result,1,generateInput_result.length);
	gCount=generateInput_result[0];
	print("Files found: "+gCount);
	print("Finished function generateInput...");//for debug

	//start code to generate output folders
	//input:img_path, foldersArray[#]
	//output:output_dir
	//check for and eventually creates the output folders for output files
	gFoldersArray=newArray("Analysis\\", "Collage\\", "Merged\\", "Masks\\", "Masks\\Cropped\\", "Masks\\Quantified\\");
	print("Checking output folders");
	generateOutputFolders(gImgPath, gFoldersArray);
	gOutputDir=gImgPath+gFoldersArray[0]; //no user interaction required, just setting the output dire here. Requires the correct gImgPath though.
	print("Output folders check completed");
	print(gImgPath+gInputList_2[0]);

//open image sequence as stack
run("Image Sequence...", "open=["+gImgPath+"] sort");
rename("ORGstack");
n=(nSlices/5);
//generate one hyperstack per each image (5 channels: Red, Green, BF_green, BF_blue, BF_red)
run("Stack to Hyperstack...", "order=xyczt(default) channels=5 slices="+n+" frames=1 display=Color");
//generate one stack per each fluorescence channel (Red, Green)
run("Make Substack...", "channels=1 slices=1-"+n+"");
rename("RDstack");
selectWindow("ORGstack");
run("Make Substack...", "channels=2 slices=1-"+n+"");
rename("GRstack");
//remove fluo channels from BF stack
//nGR=n*4;
selectWindow("ORGstack");
run("Slice Remover", "first=1 last="+nSlices+" increment=5");
selectWindow("ORGstack");
run("Slice Remover", "first=1 last="+nSlices+" increment=4");
selectWindow("ORGstack");
run("Stack Splitter", "number="+n+"");
//   run("Stack Splitter", "number=4");
//   n=4;
//generate BF images with correct channels, with labels
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
		rename("BFstack");
		print("Renamed initial BFfile");
		} else {
		print("Concatenating BFfile "+j+" to BFstack");
		run("Concatenate...", "  title=BFstack image1=[BFstack] image2=["+windowName+" (RGB)]");
	}
}
close("*ORGstack");

//screen GR stack to rotate images
selectWindow("GRstack");
radioLabels=newArray("Top-left", "Bottom-right", "Top-right", "Correct position");
stopTransform=false;
while (stopTransform==false) {
	Dialog.createNonBlocking("Scroll to the next image to rotate");
		Dialog.addRadioButtonGroup("Tail position: ", radioLabels, 4, 1, "Correct position");
		Dialog.addCheckbox("Finished", false);
	Dialog.show();
	transf=Dialog.getRadioButton();
	finish=Dialog.getCheckbox();
	nAdj=getSliceNumber();
	if (finish==true) {
		stopTransform=true;
		} else {
			if (transf==radioLabels[1]) {
				selectWindow("GRstack");
				run("Flip Horizontally", "slice");
				selectWindow("RDstack");
				setSlice(nAdj);
				run("Flip Horizontally", "slice");
				selectWindow("BFstack");
				setSlice(nAdj);
				run("Flip Horizontally", "slice");
				selectWindow("GRstack");
			}
			if (transf==radioLabels[0]) {
				selectWindow("GRstack");
				run("Flip Vertically", "slice");
				selectWindow("RDstack");
				setSlice(nAdj);
				run("Flip Vertically", "slice");
				selectWindow("BFstack");
				setSlice(nAdj);
				run("Flip Vertically", "slice");
				selectWindow("GRstack");
			}
			if (transf==radioLabels[2]) {
				selectWindow("GRstack");
				run("Flip Horizontally", "slice");
				run("Flip Vertically", "slice");
				selectWindow("RDstack");
				setSlice(nAdj);
				run("Flip Horizontally", "slice");
				run("Flip Vertically", "slice");
				selectWindow("BFstack");
				setSlice(nAdj);
				run("Flip Horizontally", "slice");
				run("Flip Vertically", "slice");
				selectWindow("GRstack");
			}
	}
	close("Scroll to the next image to rotate");
}

//generate a collage
setBatchMode("hide");/// setbatchmode setting to lower memory usage
call("java.lang.System.gc");//clears some extra memory
selectWindow("BFstack");
imageCalculator("Add create stack", "BFstack","RDstack");
rename("partOverlay");
imageCalculator("Add create stack", "partOverlay","GRstack");
rename("OVstack");
selectWindow("GRstack");
run("RGB Color", "slices");
run("Duplicate...", "title=GRstackRGB duplicate");
run("Combine...", "stack1=GRstack stack2=BFstack");
rename("partTop");
selectWindow("RDstack");
run("Duplicate...", "title=RDstackQuant duplicate");
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
	selectWindow("RDstackQuant");
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
selectWindow("RDstackQuant");
run("Image Sequence... ", "format=TIFF use save=["+gOutputDir+gFoldersArray[3]+"]");
close("GRstackRGB");
call("java.lang.System.gc");//clears some extra memory
setBatchMode("exit and display");
//fluorescence quantification
var ThrLow=20;
var ThrUpp=255;
selectWindow("RDstackQuant");
setSlice(1);
setAutoThreshold("Default dark");
setThreshold(ThrLow, ThrUpp);
run("Threshold...");
waitForUser("Select a threshold that can fit all open images, then click 'Set' and confirm. Press 'Ok' in THIS window when done.");
getThreshold(ThrLow, ThrUpp);
print("retrieved thresholds: "+ThrLow+", "+ThrUpp);
close("Threshold");
run("Set Measurements...", "area mean min area_fraction limit redirect=None decimal=3");
run("Clear Results");
for (i=0; i<nSlices; i++) {
	j=i+1;
	setSlice(j);
	run("Measure");
}
run("Read and Write Excel", "file=["+gOutputDir+"Detailed_Analysis.xlsx] sheet=TotalFluo dataset_label=[Thresholded Fluo]");
close("Results");
waitForUser("Draw a loose ROI around the tail. Check the size fits all the images. Press 'OK' when ready to measure");
roiManager("Add");
roiManager("Select", 0);
roiManager("Rename", "TailFluo");
roiManager("Save", ""+gOutputDir+"TailFluo.roi");
close("ROI Manager");
for (i=0; i<nSlices; i++) {
	j=i+1;
	setSlice(j);
	waitForUser("Move the ROI to the correct position ");
	run("Measure");
	run("Duplicate...", "use");
	label="Cropped_"+getMetadata("Label");
	setMetadata("Label", label);
	if (i==0) {
		rename("CropStack");
		selectWindow("RDstackQuant");
		} else {
		//print("Concatenating cropped images");
		image2=getTitle();
		run("Concatenate...", "  title=CropStack image1=[CropStack] image2=["+image2+"]");
		selectWindow("RDstackQuant");
	}
}
run("Read and Write Excel", "file=["+gOutputDir+"Detailed_Analysis.xlsx] sheet=TailFluo dataset_label=[Thresholded Fluo]");
run("Clear Results");
close("Results");
selectWindow("CropStack");
run("Hide Overlay");
run("Image Sequence... ", "format=TIFF use save=["+gOutputDir+gFoldersArray[4]+"]");
particleQuant(gOutputDir);
call("java.lang.System.gc");//clears some extra memory
print("Analysis terminated");

//function to get an input file folder and an array with a file list (raw list)
function inputListCheck() {
	vImgPath=getDirectory("Choose the root directory with the images to be analyzed");
	vInputList_1=getFileList(vImgPath);
	while (lengthOf(vInputList_1)==0) {
		Dialog.create("Select input directory");
			Dialog.addMessage("The specified path contains no files. Specify another path or press Cancel to exit macro");
		Dialog.show();
		vImgPath=getDirectory("Choose the directory with the images to be analyzed");
	}
	print("Path from function inputListCheck");
	print(vImgPath);
	vInputList_1=getFileList(vImgPath); //array
	inputListCheck_result=newArray(vInputList_1.length+1);
	inputListCheck_result=Array.concat(vImgPath,vInputList_1);
	return inputListCheck_result;
}

//function to generate a clean input list ////added
//input: inputList_1[#], ext
//output: j (# of elements in new array), vFileList[ARR] (array with cured file names)
function generateInput(inputList_1, vExt) {	
	count=0;
	print("Function generate input started. Variables:");
	print("inputList_1 contains "+inputList_1.length+" elements. Extension = "+vExt);
	print("Examples: "+inputList_1[0]+", "+inputList_1[1]);
	vFileList=newArray(inputList_1.length);
	for (i=0; i<inputList_1.length; i++) {
		if (endsWith(inputList_1[i], vExt)) {
			name=inputList_1[i];
			vFileList[count]=name;
			count++;
		}
	}
	if (count==0) {
		exit("No files of the indicated extension found. Exiting");
	}
	vFileList=Array.trim(vFileList, count);
	print("Size of initial file list: "+inputList_1.length);
	print("End of file scouting. Array size: "+vFileList.length);
	generateInput_result=newArray(vFileList.length+1);
	generateInput_result=Array.concat(count,vFileList);
	return generateInput_result;
}

//function to generate output folders where to save files during the analysis
//input: img_path, foldersArray
//output: output_dir
function generateOutputFolders(vImgPath, vFoldersArray) {
	//start code to generate output folders
	//input:img_path, foldersArray[#]
	//output:output_dir
	//check for and eventually creates the output folders for output files
	outputDir=getDirectory("Choose the root directory where to create the Analysis folders");
	outputExists=File.isDirectory(outputDir+vFoldersArray[0]);
	if (outputExists==0) {
		File.makeDirectory(outputDir+vFoldersArray[0]);
		print("Created main output directory");
	}
	for (i=1; i<vFoldersArray.length; i++) {
		output_exists=File.isDirectory(outputDir+vFoldersArray[0]+vFoldersArray[i]);
		if (output_exists==0) {
			File.makeDirectory(outputDir+vFoldersArray[0]+vFoldersArray[i]);
			print("Created directory "+outputDir+vFoldersArray[0]+vFoldersArray[i]);
			} else {
				print("Using existing directory "+outputDir+vFoldersArray[0]+vFoldersArray[i]);
		}
	}
}

////function to prepare for quantification
//input: processedStack[#], set, output_dir
//output: -
function particleQuant(output_dir) {
	selectWindow("CropStack");
	setBatchMode(true);
	setSlice(1);
	//run("Gaussian Blur...", "sigma=1 stack");
	setThreshold(ThrLow, ThrUpp);
	//setOption("BlackBackground", false);
	run("Convert to Mask", "method=Default background=Dark");
	//run("Erode", "stack");
	//run("Dilate", "stack");
	run("Open", "stack");
	run("Close-", "stack");
	run("Watershed", "stack");
	//selectWindow("Log"); 
	//saveAs("Text", output_dir+"Thr-list_Red fluorescence.txt"); 
	run("Set Measurements...", "area area_fraction stack redirect=None decimal=2");
	setBatchMode(false);
	for (i=0; i<nSlices; i++) {
		j=i+1;
		setSlice(j);
		//Check particle size
		run("Analyze Particles...", "size=30-Infinity show=Overlay display exclude clear include summarize");
		run("Read and Write Excel", "file=["+output_dir+"Detailed_Analysis.xlsx] sheet=PartQuant dataset_label=[Slide "+j+"]");
		run("Clear Results");
	}
	close("Results");
	selectWindow("CropStack");
	run("Image Sequence... ", "format=JPEG use save=["+gOutputDir+gFoldersArray[5]+"]");
	Table.rename("Summary of CropStack", "Results");
	run("Read and Write Excel", "file=["+output_dir+"Detailed_Analysis.xlsx] sheet=Summary dataset_label=[Cropped Tail Fluo]");
}