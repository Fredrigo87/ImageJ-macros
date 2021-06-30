//Macro for quantification of nuclear DAB staining (IHC) and normalization over nuclear staining (haematoxylin)

//Verify software requirements
//
//version required for checking plugin availability (Read and write excel)
requires("1.43f"); 
//code to check if Results to Excel is installed
List.setCommands;
if (List.get("Read and Write Excel")=="") {
  exit("Plugin ResultsToExcel is not installed. Install plugin and run the macro again.");
}

gProcessedStack=newArray("IHC", "nuclei_stack", "ki67_stack"); //array to define windows labels to keep track of the analysis steps/windows. The appropriate value is chosen via "set" variable
gProcessedDir=newArray("\\Stacks\\nuclei\\", "\\Stacks\\Ki67\\");
//WARNING: DO NOT change the order of the items below. If adding more, use escaped slash "\\", adding it also at the end, otherwise it will be integrated in filename.
gFoldersArray=newArray("Analyzed\\","","Combined_img\\","Combined_img\\Collage\\","Combined_img\\Overlay\\","Excels\\","Stacks\\","Stacks\\ORG\\","Stacks\\nuclei\\","Stacks\\nuclei\\BCadj\\","Stacks\\ki67\\","Stacks\\ki67\\BCadj\\","Stacks\\Cleaned\\", "Stacks\\nuclei\\Processed\\", "Stacks\\ki67\\Processed\\"); 

//Macro code start
//
//Retrieve variables from user
//Selecting code block to execute, based on previously performed partial analysis
	//0 = new analysis, 1 = from thresholds, images already cleaned, 2 = Stack analysis only, 3 = re-analysis of already analyzed images
	//input: user
	//output: resumetxt, resume
	resumetxt=newArray("New analysis", "Use cleaned images", "Analysis only", "Repeat analysis");
	separator=newArray("_","-","Space","Other");
	Dialog.create("Ki67 expression analysis in IHC sections")
		Dialog.addMessage("Is the analysis being started from scratch, being resumed from stacks thresholding, from stack analysis \nor being repeated for some specific samples?");
		Dialog.addRadioButtonGroup("Resume", resumetxt, 4, 1, "New analysis");
		Dialog.addMessage("Insert the extension format of the images in the stack, without the dot");
		Dialog.addString("Extension format:","tif");//ext
		Dialog.addCheckbox("Is analysis resuming from an unfinished previous run?", false);//partial
		Dialog.addCheckbox("Do images need to be checked for artifacts/speks?", false);//manual
		Dialog.addRadioButtonGroup("Separator", separator, 2, 2, "_");//separator
	Dialog.show();
	//gResume = indicates at what stage to start the analysis from
	gResume=Dialog.getRadioButton();
	gExt=Dialog.getString();
	gExtLen=lengthOf(gExt)+1;
	gPartial=Dialog.getCheckbox();
	gManual=Dialog.getCheckbox();
	gSeparator=Dialog.getRadioButton();
	
	//separator: user input for "Other" and transformation of "Space" into " "
	if (gSeparator=="Other") {
		Dialog.create("Select extension type");
			Dialog.addString("Type the separator used (no other characters, no spaces:",";");
		Dialog.show();
		gSeparator=Dialog.getString();
		} else if (gSeparator=="Space") {
			gSeparator=" ";//need to check if correct
	}
	
	if (gResume=="New Analysis") {
		gResume=0;
		} else if (gResume=="Use cleaned images") {
			gResume=1;
			} else if (gResume=="Repeat analysis") {
				gResume=3; //need to implement code to repeat analysis on some subset of images
				} else {
					gResume=2;
	}
///////////////////////////////////////
//GENERATE PATHS AND INPUT FILE LISTS
		
	//FUNCTION: get input file list
	if (gResume == 0) {
		print("Starting inputListCheck function...");
		inputListCheck_result=inputListCheck();
		gInputList_1=Array.slice(inputListCheck_result,1,inputListCheck_result.length);
		gImgPath=inputListCheck_result[0];
		print("Function inputListCheck finished.");
	
		//FUNCTION: generate a clean input list (only image files)
		//input: gInputList_1[#], gExt
		//output: j, vFileList[#]
		print("Starting function generateInput...");
		generateInput_result=generateInput(gInputList_1, gExt);
		gInputList_2=Array.slice(generateInput_result,1,generateInput_result.length);
		gCount=generateInput_result[0];
		print("Files found: "+gCount);
		print("Finished function generateInput...");//for debug
		} else {
			gCleanedPath=getDirectory("Choose the root directory with the images to be analyzed");
			gImgPath = gCleanedPath + gFoldersArray[0] + gFoldersArray[12];
			print(gImgPath);
			gInputList_2 = getFileList(gImgPath);
			gCount = gInputList_2.length;
			gExt = "jpg";
			gExtLen=lengthOf(gExt)+1;				
	}
	
	//start code to generate output folders
	//input:img_path, foldersArray[#]
	//output:output_dir
	//check for and eventually creates the output folders for output files
	print("Checking output folders");
	generateOutputFolders(gImgPath, gFoldersArray);
	gOutputDir=gImgPath+gFoldersArray[0]; //no user interaction required, just setting the output dire here. Requires the correct gImgPath though.
	print("Output folders check completed");
	
	////call function to split an example file name into parameters
	//function to parse parameters from file name
	//input: inputList_2[#], example, ext_len, separator
	//output: Str1[#], n
	print("Starting function paramFromFilename...");//for debug
	paramFromFilename_result=paramFromFilename(gExtLen, gSeparator, gInputList_2);
	gStr1=Array.slice(paramFromFilename_result,3,paramFromFilename_result.length);
	gN=paramFromFilename_result[0];
	gPartN=paramFromFilename_result[1];
	gPlaceholder=paramFromFilename_result[2];
	print("Main parameter to be used: "+gStr1[gN]);
	print("Finishing function paramFromFilename...");//for debug	
	
	//call function to check if it's ex novo analysis or partial analysis
	//Leave the partial analysis check whithin the function, as it will anyway return the final input list array
	//input: vPartial, vStr1, vN, vPartN, vPlaceholder, vInputList_2
	//output: gCount, gInputList_3
	print("Starting function partialAnalysis...");//for debug
	partialAnalysis_result=partialAnalysis(gPartial, gStr1, gN, gPartN, gPlaceholder, gInputList_2);
	gInputList_3=Array.slice(partialAnalysis_result,1,partialAnalysis_result.length);
	//gPlaceholder=partialAnalysis_result[0];
	gCount=partialAnalysis_result[0];
	print("Finishing function partialAnalysis...");//for debug

	
///////////////////////////////////////
//FUNCTIONS AND CODE TO PROCESS IMAGES
	//code to decide which stack to open, if analysis is new or resuming
	//resume_BCA=newArray(File.exists(output_dir+"BCA_nuclei_stack.csv"),File.exists(output_dir+"BCA_ki67_stack.csv")); //first nuclei stack, then ki67
	gSet=0;
	print("Starting function openStack...");
		openStack_result=openStack(gImgPath, gProcessedStack, gSet, gExtLen, gOutputDir, gInputList_3);//verify that img_path works well for input_path. //might be unnecesary to parse processedStack as it's global
		gStackID=openStack_result[0];
		gFrameTitle=Array.slice(openStack_result, 1, openStack_result.length);
	print("Function openStack finished.");
///////////////////////////////////////
//CHECK CODE FROM HERE
//////////////////////////////////////
	print("Starting function stackCrop...");
	stackCrop(gOutputDir, gManual, gExtLen, gStackID);
	print("Function stackCrop finished.");
	print("Starting function stacksFromChannels...");
	stacksFromChannels(gN, gCount, gOutputDir, gStr1, gInputList_3, gStackID, gFrameTitle);
	print("Function stacksFromChannels finished.");
	print("Starting function BCAdjustment...");
	BCAdjustment(gOutputDir, gProcessedStack);
	print("Function BCAdjustment finished.");

	
	print("Starting function particleQuant on nuclei...");
	particleQuant(1, gOutputDir, gProcessedStack);
	print("Function particleQuant on nuclei finished.");
	print("Starting function particleQuant on ki67...");
	particleQuant(2, gOutputDir, gProcessedStack);
	print("Function particleQuant on ki67 finished.");

	print("Starting function thresholdNuclei...");
	gPS_min=thresholdNuclei();
	print("Function thresholdNuclei finished. Threshold used: "+gPS_min);
	print("Starting function resultQuant...");
	resultQuant(gN, gCount, gPS_min, gOutputDir, gSeparator);
	print("Function resultQuant finished.");
	print("Analysis finished");
	
	waitForUser("Analysis finished, closing windows. Check output files");
	run("Close All");
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////Starting code for functions called

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
	//path = vImgPat; // leave this variable so to parse a string the the Array.concat() function
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
//function to parse parameters from file name. This is used to correctly label saved files.
//global variables accessed: 
//input: gPartial, gExtLen, gSeparator, gInputList_2[#]
//output: vN, vPartN, vPlaceholder, vStr1
function paramFromFilename(vExtLen, vSeparator, vInputList_2) {
	print("Checking file names to detect parameters...");
	do {example=vInputList_2[0];
		example=substring(example, 0, (lengthOf(example)-vExtLen));
		vStr1=split(example,vSeparator);
		vN=vStr1.length;
		print("Example file name: "+example);
		if (vN==0) {
			Dialog.create("Separator error");
				Dialog.addMessage("Could not find the indicated separator within file name.\nCheck the file name!");
				Dialog.addMessage(example);
				Dialog.addString("Type the separator used",";");
			Dialog.show();
			vSeparator=Dialog.getString();		
		}
	} while (vN==0); //here n is the number of parameters
	print("Checking for consistency of parameters within file name across files...");
	
	//This block of code checks file names consistency, so that the extraction of parameters from file names can be applied to all files
	k=0;
	m=0;
	//this creates an average of parameters number, to compare the file names to
	for (i=0; i<vInputList_2.length; i++) {
		example=vInputList_2[i];
		print(example); //debug
		example=substring(example, 0, (lengthOf(example)-vExtLen));
		vStr1=split(example,vSeparator);
		m=m+vStr1.length;
	}
	vN=round(m/i);
	//this checks if number of parameters in file name (n) corresponds to the average and reports the files which don't.
	for (i=0; i<vInputList_2.length; i++) {
		example=vInputList_2[i];
		example=substring(example, 0, (lengthOf(example)-vExtLen));
		vStr1=split(example,vSeparator);
		m=vStr1.length;
		if (m!=vN) {
			print(vInputList_2[i]);
			k++;
		}
	}
	if (k!=0) {
		exit("Found inconsistencies in filename. See above files");
		} else {
		Dialog.create("Select parameters");
			Dialog.addMessage(m+" parameters were found. Select the main one to use (i.e. Experiment number)");
			for (i=0; i<vStr1.length; i++) {
				Dialog.addMessage(i+" = "+vStr1[i]);
			}
			Dialog.addNumber("Main parameter: ", 0);
			if (gPartial==true) {
				Dialog.addNumber("Indicate the number of the parameter that will be used for resuming", 0);
				Dialog.addString("Specify the number to continue analysis from:", "");
				Dialog.addMessage("To correctly resume analysis, it's vital that indices in file names have \nleading zeroes (so not 'image_1' but 'image_01'");
			}
		Dialog.show();
		vN=Dialog.getNumber();	//here n is the main parameter position, not the parameter itself	
		if (gPartial==true) {
				vPartN=Dialog.getNumber(); //vPartN is the parameter position in case of partial analysis (when resuming)
				vPlaceholder=parseInt(Dialog.getString()); //vPlaceholder is the actual parameter to resume analysis from (i.e. "15" for image_15)
			} else {
				vPartN=-1;
				vPlaceholder="Tot";
			}
		print("File name check completed");
	}
	paramFromFilename_result=newArray(vStr1.length+3);
	paramFromFilename_result=Array.concat(vN, vPartN, vPlaceholder, vStr1);
	return paramFromFilename_result;
}
//code to resume a partial analysis
//input: vPartial, vStr1, vN, vPartN, vPlaceholder, vInputList_2
//output: vCount, vInputList_3
function partialAnalysis(vPartial, vStr1, vN, vPartN, vPlaceholder, vInputList_2) {
	vInputList_3=Array.copy(vInputList_2);
	if (vPartial==false) {
		Array.sort(vInputList_3);
		vCount=vInputList_3.length;
		//vPlaceholder=vN;	<-- CHECK THIS, UNCOMMENT IF NECESSARY
		} else {
			vCount=0;
			for(i=0; i<vInputList_2.length; i++) {
				vStr1=split(vInputList_2[i],vSeparator);
				if (parseInt(vStr1[vPartN])==vPlaceholder) {
					vInputList_3[vCount]=vInputList_2[i];
					vCount++;
					vPlaceholder++;				
				}
			}
			if (vCount==1) {
				exit("Found only 1 file, with the specified keyword.\nThis macro requires at least 2 files to proceed. Exiting");
			}
			if (vCount==0) {
				showMessageWithCancel("Warning","No files with the specified keyword were found. \nPress 'Ok' to ignore keyword and process all files or 'Cancel' to exit the macro.");
				vInputList_3=Array.copy(vInputList_2);
				Array.sort(vInputList_3);
				//placeholder="Tot";				
				} else {
					print("Found "+vCount+" files.");
					vInputList_3 = Array.trim(vCount); //this adapts inputList_3 to the size of the files actually needed for the analysis. 
					Array.sort(vInputList_3);
					Array.show(vInputList_3);// for debug
			}
	}
	partialAnalysis_result=newArray(vInputList_3.length+1);
	partialAnalysis_result=Array.concat(vCount,vInputList_3);
	return partialAnalysis_result;
}
//function to generate output folders where to save files during the analysis
//input: img_path, foldersArray
//output: output_dir
function generateOutputFolders(vImgPath, vFoldersArray) {
	//start code to generate output folders
	//input:img_path, foldersArray[#]
	//output:output_dir
	//check for and eventually creates the output folders for output files
	output_exists=File.isDirectory(vImgPath+vFoldersArray[0]);
	if (output_exists==0) {
		File.makeDirectory(vImgPath+vFoldersArray[0]);
		print("Created main output directory");
	}
	for (i=1; i<vFoldersArray.length; i++) {
		output_exists=File.isDirectory(vImgPath+vFoldersArray[0]+vFoldersArray[i]);
		if (output_exists==0) {
			File.makeDirectory(vImgPath+vFoldersArray[0]+vFoldersArray[i]);
			print("Created directory "+vImgPath+vFoldersArray[0]+vFoldersArray[i]);
			} else {
				print("Using existing directory "+vImgPath+vFoldersArray[0]+vFoldersArray[i]);
		}
	}
}
//function to generate stacks and name slices
//input:img_path (ARG), processedStack[#], set, partial, img_path, resume_dir, placeholder, inputList_3[#], output_dir, ext_len
//output://stack_window, //count, stackTitle[#], stackDone //name_length
function openStack(vImgPath, vActiveStack, vSet, vExtLen, vOutputDir, vInputList_3) {	//vActiveStack = gProcessedStack
	opStack=isOpen(vActiveStack[vSet]);
	if (opStack==true) {
		selectWindow(vActiveStack[vSet]);//checks a window with correct name is open
		isStack=getInfo("slice.label");//checks the open window is a stack
		if(isStack!=0){
			stack_window=true;
			} else {
				stack_window=false;
		}
		} else {
				stack_window=false;
	}
		//print("stack_window status = "+stack_window);//debug
		//run("Image Sequence...", "open=["+input_path+"] sort"); //Image sequence: use "Sort names" function to override system-specific settings for file loading, that would reflect on image order
		//vImgPath="D:/Work_Folder/Ki67_macro/Source/";
		//original=getFileList(vImgPath);
		vLabels=newArray(vInputList_3.length);
		setBatchMode(true);
		if (stack_window==false) {
			print("Opening file '"+vImgPath+vInputList_3[0]+"'");
			open(vImgPath+vInputList_3[0]);
			vLabels[0]=getTitle();
			vLabels[0]=substring(vLabels[0],0,lengthOf(vLabels[0])-vExtLen);
			rename(vActiveStack[vSet]);
			for (i=1; i<vInputList_3.length; i++) {
				open(vImgPath+vInputList_3[i]);
				vLabels[i]=getTitle();
				vLabels[i]=substring(vLabels[i],0,lengthOf(vLabels[i])-vExtLen);
				print("Labels & co: "+i+"+"+vLabels[i]+"+"+vInputList_3[i]);
				run("Concatenate...", "  title="+vActiveStack[vSet]+" image1="+vActiveStack[vSet]+" image2="+vInputList_3[i]+" image3=[-- None --]");
			} 
			}else {
				setSlice(1);		
		}
		selectWindow(vActiveStack[vSet]);
		for (i=0; i<nSlices; i++){
			j=i+1;
			setSlice(j);
			setMetadata("Label", ""+vLabels[i]+"");	
		}
		//rename(vActiveStack[vSet]);
		vStackID=getImageID(); //it's the stack ID			
		setBatchMode(false);
		selectWindow(vActiveStack[vSet]);
		setSlice(1);
		print(getMetadata("Label"));
	//save the list of input files (inputList_3)
	fileName="01_file_names_";
	l=0;
	previousList=File.exists(vImgPath+fileName+l+".csv");
	while (previousList==true) {
		l++;
		previousList=File.exists(vImgPath+fileName+l+".csv");
	}
	if (l!=0) {
		print("List of file names was already generated previously, "+l+" times");
		print("Saving list of file names as "+fileName+l+".csv");
	}
	Array.show("Results (row numbers)", vInputList_3);
	Table.rename("Results", fileName);
	saveAs("Results", vImgPath+fileName+l+".csv");
	run("Close");
	//save the labels (slice labels of stack)
	fileName="02_Slice_names_";
	l=0;
	previousList=File.exists(vOutputDir+fileName+l+".csv");
	while (previousList==1) {
		l++;
		previousList=File.exists(vOutputDir+fileName+l+".csv");
	}
	if (l!=0) {
		print("List of slice names was already generated previously, "+l+" times");
		print("Saving list of slice names as "+fileName+l+".csv");
	}
	Array.show("Results (row numbers)", vLabels);
	Table.rename("Results", fileName);
	saveAs("Results", vOutputDir+fileName+l+".csv");
	run("Close");
	
	selectImage(vStackID);
	setSlice(1);
	openStack_result=newArray(vLabels.length+1);
	openStack_result=Array.concat(vStackID, vLabels);
	print("end of openStack function"); //debug
	return openStack_result;
}
//function to cut out problematic areas of the pictures in the stack
//input: manual, output_dir, ext_len
//output: title. A stack of processed images
function stackCrop(output_dir, manual, ext_len, stackID) {
	selectImage(stackID);
	title=getTitle();// corresponds to processedStack[set] --> IHC, nuclei_Stack, ki67_stack
	if (manual==true) {
		run("Colors...", "foreground=white background=white selection=yellow");
		setSlice(1);
		waitForUser("Scroll the image stack and remove blurred/dirty areas.\n1. Select the polygon tool\n2. Contour the area to be removed on the image. Double-click to close the selection\n3. Press 'Canc' to delete the area\n4. Elaborate all images then press 'Ok' in this window to proceed");
		setSlice(1);
		run("Select None");
		rename(title);	
		for (i=0; i<nSlices; i++) {
			j=i+1;
			setSlice(j);
			title=getMetadata("Label");
			saveAs("Jpeg", output_dir+gFoldersArray[12]+title+".jpg");//Stacks/Cleaned
		}
	}
}

//code to generate nuclei and ki67 initial stacks, from cropped, BC-adjusted images, and to save the stacks in output_folder
//
//
function stacksFromChannels(n, count, output_dir, Str1, inputList_3, stackID, frameTitle) {
	//code is not completely generic, the IHC window is called via imageID, while the other stack via selectWindow. Fix. DEBUG
	//setBatchMode(true);
	selectImage(stackID);
	setSlice(1);
	run("Duplicate...", "title="+gProcessedStack[0]+" duplicate"); /////////////////was ORG_stack!!
	selectImage(stackID);	
	run("Split Channels");
	selectWindow(gProcessedStack[0]+" (green)");
	run("Close");
	selectWindow(gProcessedStack[0]+" (red)");
	rename("nuclei_stack");
	selectWindow(gProcessedStack[0]+" (blue)");
	rename("ki67_stack");
	selectWindow(gProcessedStack[0]);
	stackID=getImageID(); //stackID is now ORG_stack. IHC was closed when splitting channels
	selectImage(stackID);
	setSlice(1);
	j=0;
	for (k=0; k<count; k++) {
		j=k+1;
		selectWindow("nuclei_stack");
		setSlice(j);
		setMetadata("Label", "Nucl_RAW_"+frameTitle[k]+"");
		selectWindow("ki67_stack");
		setSlice(j);
		setMetadata("Label", "Ki67_RAW_"+frameTitle[k]+"");
	}
	selectWindow("ki67_stack");
	run("Image Sequence... ", "format=JPEG use save=["+output_dir+gFoldersArray[10]+"]");
	print("Stack saved in "+output_dir+gFoldersArray[10]);
	rename("ki67_stack");
	selectWindow("nuclei_stack");
	run("Image Sequence... ", "format=JPEG use save=["+output_dir+gFoldersArray[8]+"]");
	print("Stack saved in "+output_dir+gFoldersArray[8]);
	rename("nuclei_stack");
	selectWindow(gProcessedStack[0]);
	run("Image Sequence... ", "format=JPEG use save=["+output_dir+gFoldersArray[7]+"]");
	print("Stack saved in "+output_dir+gFoldersArray[7]);
	rename(gProcessedStack[0]);
	//setBatchMode(false);
}

//function to manually adjust brightness/contrast and save adjusted stack
//input: output_dir, processedStack[#]
//output: -
//Code for BC homogeneization of stacks
function BCAdjustment(output_dir, processedStack) { //need to implement resuming incomplete analysis from placeholder -- at the inputList level
	for (l=1; l<3; l++) {
		k=l-1;
		selectWindow(processedStack[l]);
		count=nSlices();
		//print("\\Clear");
		//resume code from here
		if (l==1) {
			label="nuclei of";
			BCA_min=130;
			BCA_max=140;
			} else {
			label="Ki67+";
			BCA_min=120;
				BCA_max=130;
		}
		setMinAndMax(BCA_min, BCA_max);
		run("Brightness/Contrast...");
		selectWindow(processedStack[l]);
		waitForUser("Check for optimal brightness/contrast to identify "+label+" cells. Compare with original stack. Then click OK");
		selectWindow(processedStack[l]);
		getMinAndMax(BCA_min, BCA_max);
		selectWindow("B&C"); ///line added on 21.12.19
		Dialog.create("Adjust BC");
			Dialog.addCheckbox("Use fixed min/max values for "+processedStack[l]+"? Fill below", true);
			Dialog.addString("Min: ", BCA_min);
			Dialog.addString("Max: ", BCA_max);
			Dialog.addCheckbox("Check individual images for B/C", false);
		Dialog.show();
		BCA_auto=Dialog.getCheckbox();
		BCA_min=parseInt(Dialog.getString());
		BCA_max=parseInt(Dialog.getString());
		overrideBC=Dialog.getCheckbox();
		name=newArray(count);
		Array_min=newArray(count);
		Array_max=newArray(count);
		BCA_min_curr=BCA_min;
		BCA_max_curr=BCA_max;
		for (i=0; i<count; i++) {
			j=i+1;
			selectWindow(processedStack[l]);
			setSlice(j);
			if (BCA_auto==true&&overrideBC==false) {
				selectWindow(processedStack[l]);//check it's ok
				setMinAndMax(BCA_min, BCA_max);
				run("Apply LUT", "slice");
				} else {
				run("Brightness/Contrast...");
				setMinAndMax(BCA_min_curr, BCA_max_curr);
				waitForUser("Adjust min/max. Do not click any button on the 'B&C' window");
				selectWindow(processedStack[l]);//check it's ok
				getMinAndMax(BCA_min_curr, BCA_max_curr);
				if (BCA_min_curr==BCA_max_curr) {
					BCA_max_curr=BCA_max_curr+5;
					setMinAndMax(BCA_min_curr, BCA_max_curr);
				}
				run("Apply LUT", "slice");
				selectWindow("B&C");
				run("Close");
			}
			vTitle=getMetadata("Label");
			setResult("Slice", i, vTitle);
			setResult("Min", i, BCA_min_curr);
			setResult("Max", i, BCA_max_curr);
			//makes a backup copy of BC-adjusted image and closes duplicated window
			name[i]=getInfo("slice.label");
			nameLength=lengthOf(name[i]);
			name[i]=substring(name[i], 9, nameLength);
			if (l==1) {
				name[i]="Nucl_BCA_"+name[i];
				} else {
					name[i]="Ki67_BCA_"+name[i];
			}
			run("Make Substack...", " slices="+j);
			selectWindow("Substack ("+j+")");
			rename(name[i]);
			setMetadata("Label", name[i]);
			if (l==1) {
				q=9;
				} else {
				q=11;
			}
			saveAs("Jpeg", output_dir+gFoldersArray[q]+name[i]+".jpg");
			print("File saved in "+output_dir+gFoldersArray[q]+name[i]);
			run("Close");
			print(name[i]);
			Array_min[i]=BCA_min;
			Array_max[i]=BCA_max;
		}
		selectWindow("Log");
		saveAs("Text", output_dir+processedStack[l]+".txt");
		fileName="03_Min-Max_values_"+processedStack[l]+"_";
		Array.show("Results (row numbers)", name, Array_min, Array_max);
		Table.rename("Results", "Min-Max BC values");
		saveAs("Results", output_dir+fileName+gN+".csv");
		run("Close");
	}
	//selectWindow(processedStack[l]);
	if (isOpen("B&C")==true) {
		selectWindow("B&C");
		run("Close");
	}
}

////function to prepare for quantification
//input: processedStack[#], set, output_dir
//output: -
function particleQuant(set, output_dir, processedStack) {
	selectWindow(processedStack[set]);
	setBatchMode(true);
	setSlice(1);
	run("Gaussian Blur...", "sigma=1 stack");
	setAutoThreshold("Default no-reset");
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=Default background=Light calculate list");
	run("Erode", "stack");//step added in v3
	run("Dilate", "stack");//step added in v3
	run("Close-", "stack");
	run("Watershed", "stack");
	selectWindow("Log"); 
	saveAs("Text", output_dir+"Thr-list_"+processedStack[set]+".txt"); 
	setBatchMode(false);
}

////function to determine optimal threshold for nuclei quantification
//input: -
//output: -
function thresholdNuclei() {
	setBatchMode(false);
	Proceed=false;
	PS_min=160;
	selectWindow("nuclei_stack");
	//run("Make Substack...", " slices=1");
	setSlice(1);
	while (Proceed==false) {
		selectWindow("nuclei_stack");
		run("Remove Overlay");
		run("Analyze Particles...", "size="+PS_min+"-Infinity circularity=0.20-1.00 show=[Overlay Masks] display clear include stack");
		run("Labels...", "color=white font=9");
		waitForUser("Check nuclei segmentation with particle size set at "+PS_min);
		Dialog.create("Adjust Particle Size");
			Dialog.addMessage("Use this min value for Analyze particle");
			Dialog.addString("Min: ", PS_min);
			Dialog.addCheckbox("Check this box to confirm the value and proceed to analysis", false);
		Dialog.show();
		PS_min=parseInt(Dialog.getString());
		Proceed=Dialog.getCheckbox();
	}
	run("Remove Overlay");
	run("Clear Results");
	close("Results");
return PS_min;	
}
////function to quantify images
//input: n, count, magn, output_dir, separator
//output: -
function resultQuant(n, count, vPS_min, output_dir, separator) { //var magn is no longer needed as a live size check was introduced
	setBatchMode(true);
	run("Set Measurements...", "area redirect=None decimal=1");
	for (i=0; i<count; i++) {
		//setup variables and open image
		j=i+1;
		//selectWindow("ORG_stack");
		selectWindow("IHC");
		setSlice(j);
		name=getMetadata("Label");
		Str1=split(name, separator);
		selectWindow("nuclei_stack");
		run("Make Substack...", " slices="+j);
		selectWindow("Substack ("+j+")");
		print("Saving jpeg image of processed nuclei as "+output_dir+gFoldersArray[13]+name+"_processed_nuclei.jpg");
		saveAs("Jpeg", output_dir+gFoldersArray[13]+name+"_processed_nuclei.jpg");
		rename(name+"_nuclei");
		//Particles area is set based on pixels. The code below allows to set the right parameter to count the nuclei of the right size
		//The command below also displays Results, so use it to record individual measurements
		//run("Analyze Particles...", "size="+vPS_min+"-Infinity circularity=0.20-1.00 display clear include summarize add slice");
		run("Analyze Particles...", "size="+vPS_min+"-Infinity circularity=0.20-1.00 display clear include summarize add slice");
		roiManager("Show None");/////// Check it's ok
		print("nuclei segmented for "+name+". Writing Excel of summary...");
		//The code below saves a summary Analysis file, appending each new quantification result to the file
		run("Read and Write Excel", "file=["+output_dir+gFoldersArray[5]+Str1[n]+"_Detailed_Analysis.xlsx] sheet=Nuclei dataset_label=["+j+"_"+name+"_Nuclei]");
		run("Clear Results"); // UNCOMMENT FOR INDIVIDUAL MEASUREMENTS
		close("Results"); // UNCOMMENT FOR INDIVIDUAL MEASUREMENTS
		Table.rename("Summary", "Results"); //this is to use the plugin Read and Write Excel with the Summary table
		run("Read and Write Excel", "file=["+output_dir+gFoldersArray[5]+Str1[n]+"_Analysis.xlsx] sheet=Nuclei dataset_label=["+j+"_"+name+"_Nuclei]");
		close("Results");
		//generation of nuclei image
		selectWindow(name+"_nuclei");
		roiManager("Show All without labels");
		roiManager("Set Color", "cyan");
		roiManager("Set Line Width", 0);
		roiManager("Set Fill Color", "cyan");
		run("Flatten");
		rename("FL_nuclei");
		run("Duplicate...", "title=overlay");
		selectWindow(name+"_nuclei");
		run("Close");
		roiManager("Delete");
		// generation of ki67 image
		selectWindow("ki67_stack");
		run("Make Substack...", " slices="+j);
		selectWindow("Substack ("+j+")");
		print("Saving jpeg image of ki67 nuclei as "+output_dir+gFoldersArray[14]+name+"_processed_Ki67.jpg");
		saveAs("Jpeg", output_dir+gFoldersArray[14]+name+"_processed_Ki67.jpg");
		rename(name+"_ki67");
		//measurement of Ki67, with flattened image output
		run("Clear Results");
		print("Starting quantification of Ki67 nuclei");
		//The code below saves a summary Analysis file, appending each new quantification result to the file
		//run("Analyze Particles...", "size="+vPS_min+"-Infinity circularity=0.20-1.00 display clear include summarize add slice");
		run("Analyze Particles...", "size="+vPS_min+"-Infinity circularity=0.20-1.00 display clear include summarize add slice");
		roiManager("Show None");/////// Check it's ok
		//The code below saves a summary Analysis file, appending each new quantification result to the file
		run("Read and Write Excel", "file=["+output_dir+gFoldersArray[5]+Str1[n]+"_Detailed_Analysis.xlsx] sheet=Ki67 dataset_label=["+j+"_"+name+"_Ki67]");
		run("Clear Results"); // UNCOMMENT FOR INDIVIDUAL MEASUREMENTS
		close("Results"); // UNCOMMENT FOR INDIVIDUAL MEASUREMENTS
		Table.rename("Summary", "Results");
		print("Ki67 segmented for "+name+". Writing Excel of summary...");
		run("Read and Write Excel", "file=["+output_dir+gFoldersArray[5]+Str1[n]+"_Analysis.xlsx] sheet=Ki67 dataset_label=["+j+"_"+name+"_Ki67]");
		close("Results");
		selectWindow(name+"_ki67");
		roiManager("Show All without labels");
		roiManager("Set Color", "orange");
		roiManager("Set Line Width", 0);
		roiManager("Set Fill Color", "orange");
		run("Flatten");
		rename("FL_ki67");
		selectWindow(name+"_ki67");
		run("Close");
		//generation of overlay image
		selectWindow("overlay");
		roiManager("Show All without labels");
		run("Flatten");
		print("Saving flattened image of nuclei/ki67 overlay");
		saveAs("Jpeg", output_dir+gFoldersArray[4]+name+"_FL_overlay.jpg");
		rename("FL_overlay");
		selectWindow("overlay");
		run("Close");
		//generation of combined 4-pics image
		//selectWindow("ORG_stack");
		selectWindow("IHC");
		run("Make Substack...", " slices="+j);
		selectWindow("Substack ("+j+")");
		rename("org");
		run("Combine...", "stack1=org stack2=FL_overlay");
		rename("row1");
		run("Combine...", "stack1=FL_nuclei stack2=FL_ki67");
		rename("row2");
		run("Combine...", "stack1=row1 stack2=row2 combine");
		rename("combined_"+j);
		//save output image files
		selectWindow("combined_"+j);
		print("Saving flattened combined image");
		saveAs("Jpeg", output_dir+gFoldersArray[3]+name+"_combined.jpg");
		run("Close");
		print("Finishedp rocessing image "+j);
	}
	setBatchMode(false);
}
