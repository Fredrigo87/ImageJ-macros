requires("1.52p");
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
	
	//start code to generate output folders
	//input:foldersArray[#]
	//output:output_dir
	//check for and eventually creates the output folders for output files
	print("------- Starting ZF analisys macro step 1");
	p = File.separator;
	gFoldersArray = newArray("Analysis"+p, "RotatedStacks"+p, "Cropped"+p, "Masks"+p, "Quantified"+p, "AdjThr"+p, "Collage"+p, "Overlay"+p, "allCh"+p, "noBF"+p);
	print("Setting up output folders");
	gImgPath=generateOutputFolders(gFoldersArray);
	gOutputDir=gImgPath+gFoldersArray[0];
	//gOutputDir=gImgPath+gFoldersArray[0]; //no user interaction required, just setting the output dire here. Requires the correct gImgPath though.
	print("Output folders check completed");
	//print(gImgPath+gInputList_2[0]);
	
	//FUNCTION: get input file list
	print("Starting inputListCheck function...");
	gInputList_1=inputListCheck(gImgPath);
	//gInputList_1=Array.slice(inputListCheck_result,1,inputListCheck_result.length);
	//gImgPath=inputListCheck_result[0];
	print("Function inputListCheck finished.");

	//FUNCTION: generate a clean input list (only image files)
	//input: gInputList_1[#], gExt
	//output: j, vFileList[#]
	//gExt is the extension of the files to be analyzed
	gExt="ome.tif";
	//gExt="png";
	print("Starting function generateInput...");
	generateInput_result=generateInput(gInputList_1, gExt, gOutputDir, gImgPath);
	gInputList_2=Array.slice(generateInput_result,1,generateInput_result.length);
	//gCount is the count of files with the required extension
	gCount=generateInput_result[0];
	print("Files found: "+gCount);
	
	print("Finished function generateInput...");//for debug

	fileTable=Table.open(gOutputDir+"ZF_01_Input.csv");
	imName=Table.getColumn("Image_File");
//Array.print(imName); // prints the whole array: my first image.tif, my sec image.tif
print(imName[0]); // prints the first image name
print(imName[1]); 

//save the log file for step 1
selectWindow("Log"); 
saveAs("Text", gOutputDir+"Log_macro_step_1.txt"); 

showMessage("Step 1 completed");

////////////////////////// Functions ///////////////////////////////

//function to generate output folders where to save files during the analysis
//input: img_path, foldersArray
//output: output_dir
function generateOutputFolders(vFoldersArray) {
	//start code to generate output folders
	//input:img_path, foldersArray[#]
	//output:output_dir
	//check for and eventually creates the output folders for output files
	//outputDir=getDirectory("Choose the root directory where to create the Analysis folders");
	inputDir=getDirectory("Choose the root directory with the images to be analyzed");
	outputExists=File.isDirectory(inputDir+vFoldersArray[0]);
	if (outputExists==0) {
		File.makeDirectory(inputDir+vFoldersArray[0]);
		print("Created main output directory");
	}
	outputDir=inputDir+vFoldersArray[0];
	foldersCombo=newArray(vFoldersArray[1], vFoldersArray[2], vFoldersArray[3], vFoldersArray[3]+vFoldersArray[4], vFoldersArray[5], vFoldersArray[5]+vFoldersArray[6], vFoldersArray[5]+vFoldersArray[7], vFoldersArray[5]+vFoldersArray[7]+vFoldersArray[8], vFoldersArray[5]+vFoldersArray[7]+vFoldersArray[9]);
	
	for (i=0; i<foldersCombo.length; i++) {
		output_exists=File.isDirectory(outputDir+foldersCombo[i]);
		if (output_exists==0) {
			File.makeDirectory(outputDir+foldersCombo[i]);
			print("Created directory "+outputDir+foldersCombo[i]);
			} else {
				print("Using existing directory "+outputDir+foldersCombo[i]);
		}
	}
	return inputDir;
}

//function to get an input file folder and an array with a file list (raw list)
function inputListCheck(vImgPath) {
	vInputList_1=getFileList(vImgPath);
	while (lengthOf(vInputList_1)==0) {
		Dialog.create("Select input directory");
			Dialog.addMessage("The specified path contains no files. Specify another path or press Cancel to exit macro");
		Dialog.show();
		vImgPath=getDirectory("Choose the directory with the images to be analyzed");
		vInputList_1=getFileList(vImgPath);
	}
	//print("Path from function inputListCheck");
	//print(vImgPath);
	inputListCheck_result=getFileList(vImgPath); //array
	//inputListCheck_result=newArray(vInputList_1.length+1);
	//inputListCheck_result=Array.concat(vImgPath,vInputList_1);
	return inputListCheck_result;
}

//function to generate a clean input list ////added
//input: inputList_1[#], ext
//output: j (# of elements in new array), vFileList[ARR] (array with cured file names)
function generateInput(inputList_1, vExt, gOutputDir, vImgPath) {	
	count=0;
	print("Function generate input started. Variables:");
	print("inputList_1 contains "+inputList_1.length+" elements. Extension = "+vExt);
	print("Examples: "+inputList_1[0]+", "+inputList_1[1]);
	vFileList=newArray(inputList_1.length);
	//writing a file with output dur, for next macros
	fileOutputDir=File.open(gOutputDir+"ZF_01_Dir.txt");
	print(fileOutputDir, vImgPath);
	File.close(fileOutputDir);
	//saving folders array
	folderTable=Table.setColumn("Folder_Array", gFoldersArray);
	Table.save(gOutputDir+"ZF_01_Folders.csv");
	//generating the array with files with the right extension
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
	//copying the array to a table, to be saved as input file for next macros
	fileTable=Table.setColumn("Image_File", vFileList);
	Table.save(gOutputDir+"ZF_01_Input.csv");
	print("Size of initial file list: "+inputList_1.length);
	print("End of file scouting. Array size: "+vFileList.length);
	generateInput_result=newArray(vFileList.length+1);
	generateInput_result=Array.concat(count,vFileList);
	return generateInput_result;
}
