//Macro for quantification of cell migration
//Measures % area fraction and particles count
//Output: filename list, thresholded images, binary images with counted objects overlay

// FLM, 26.08.2020

//version required for checking plugin availability (Read and write excel)
requires("1.52o"); 
//check if Results to Excel is installed
//List.setCommands;
//if (List.get("Read and Write Excel")=="") {
//  exit("Plugin ResultsToExcel is not installed. Install plugin and run the macro again.");
//}
//List of folders to be created/checked, containing output files
gFoldersArray=newArray("Analyzed\\","Thr_Images\\","Quantified_Images\\");
//main code
macro "Migration_Quantification" {
	print("\\Clear");

	waitForUser("Load the image stack. \n File > Import > Image sequence...\n Then press 'Ok'");
	gImgPath=getDirectory("current");
	waitForUser("Check the images.\n Remove scalebar if needed, then press 'Ok'.\n \n Scalebar removal\n 1. Rectangular selection over scalebar\n 2. Edit > Clear. Process all images\n 3. If black, Edit > Invert. Process all images\n 4. Click on image to remove selection");

	//function generateOutputFolders
	print("Starting function generateOutputFolders");
	generateOutputFolders(gImgPath, gFoldersArray);
	gOutputDir=gImgPath+gFoldersArray[0]; //no user interaction required, just setting the output dire here. Requires the correct gImgPath though.
	print("Output folders check completed.");

	//Creating summary table
	Table.create(summaryTable);
	Table.title "Summary Table";
	Table.headings 	"Slice"	"Name"	"Threshold"	"% Area Tot"	"Particles"	"AVG area particles"	"% Area particles";
	
	//function labelsList
	labelsList();

	//function areaPercent
	areaPercent();

	//function particleCount
	particleCount();
	
	Table.save(gOutputDir);
}

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

function labelsList() {
	slices=nSlices;
	labels=newArray(slices);
	count=newArray(slices.length);
	for (i=0; i<slices; i++) {
		j=i+1;
		setSlice(j);
		labels[i] = getMetadata("Label");
		count[i]=j;
		//print(labels[i]);
	}
	Table.setColumn("Slice", count);
	Table.setColumn("Name", labels);
	Table.update -;
}

function areaPercent() {
	title=getTitle();
	run("Split Channels");
	close("*blue*");
	close("*red*");
	rename(title);
	run("Threshold...");
	waitForUser("Scroll images and adjust threshold to select cells, then click 'Ok'. Use the highest threshold that doesn't include background");
	lower=0;
	upper=115;
	getThreshold(lower, upper);
	setThreshold(lower, upper);
	run("Convert to Mask", "method=Default background=Light list");
	run("Set Measurements...", "area_fraction redirect=None decimal=2");
	percAreaTot=newArray(slices);
	ThrList=newArray(slices);
	for (i=0; i<slices; i++) {
		j=i+1;
		setSlice(j);
		run("Measure");
		percAreaTot[i]=nResults;
		ThrList[i]=upper;
	}
	Table.setColumn("Threshold", ThrList);
	Table.setColumn("% Area Tot", percAreaTot);
	Table.update -;	
}

function particleCount() {
	run("Watershed", "stack");
	title=getTitle();
	size=false;
	min="180";
	max="Infinity";
	while (size==false) {
		Dialog.create("Particle size");
			Dialog.addMessage("Select min and max particle size to be quantified. Default = 180-Infinity\n Tip: Select the largest object that should not be quantified with an ROI.\n Then measure it and set it as minimum size. \n Scroll images to check if large clusters of cells are present.");
			Dialog.addString("Min:", min);
			Dialog.addString("Max:", max);
		Dialog.show();
		min=Dialog.getString();
		max=Dialog.getString();
		run("Analyze Particles...", "size="+min+"-"+max+" show=Masks include stack");
		Dialog.createNonBlocking("Size check");
			Dialog.addCheckbox("Check if the selected range is ok", false);
		Dialog.show();
		size=Dialog.getCheckbox();
		close("*Mask*");
	}
	run("Analyze Particles...", "size="+min+"-"+max+" show=Overlay display clear include summarize stack");
	partCount=Table.getColumn("Count");
	partAvgSize=Table.getColumn("Average Size");
	partPercentArea=Table.getColumn("%Area");
	selectWindow("Summary of "+title);
	run("Close");
	Table.setColumn("Particles", partCount);
	Table.setColumn("AVG area particles", partAvgSize);
	Table.setColumn("% Area particles", partPercentArea);
	Table.update -;
}
