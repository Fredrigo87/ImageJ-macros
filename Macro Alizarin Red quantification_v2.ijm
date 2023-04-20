//Author of the code: Federico La Manna
//Date: 20.04.2023
//Available from: Github, "https://github.com/Fredrigo87/ImageJ-macros"
//First published in [Federico La Manna, Daniel Hanhart, Peter Kloen, Andre J van Wijnen, George N. Thalmann, Marianna Kruithof-de Julio, Panagiotis Chouvardas. "Molecular profiling of osteoprogenitor cells reveals FOS as a master regulator of bone non-union". Gene]

//Macro code start
path=getDirectory("Choose the directory with the images to analyze");
File.openSequence(path, "filter=DIF");
labels=newArray(nSlices);
for (i=0; i<labels.length; i++) {
	j=i+1;
	setSlice(j);
	labels[i]=getMetadata("Label");
}

//Quantification is performed on the GREEN channel of the composite RGB image.
title=getTitle();
run("Split Channels");
close("*(blue)");
close("*(red)");
rename(title);
print("\\Clear");

//setting threshold and measuring area fraction and mean gray values (limited to selected threshold)
reiterate = false;
ThrUpp = 80; //arbitrary starting value for the analysis (value range 0-255 for 8 bit files)
run("Set Measurements...", "area mean area_fraction stack limit redirect=None decimal=2");
while (reiterate == false) {
	run("Clear Results");
	setThreshold(0, ThrUpp);
	run("Threshold...");
	waitForUser("Select a threshold that can fit all open images, then press the Enter key. Press 'Ok' in THIS window when done.");
	getThreshold(ThrLow, ThrUpp);
	print("retrieved thresholds: "+ThrLow+", "+ThrUpp);
	close("Threshold");
	setThreshold(0, ThrUpp);
	for (i=0; i<labels.length; i++) {
		j=i+1;
		setSlice(j);
		setMetadata("Label", labels[i]);
		print(labels[i]);
		run("Measure");
	}
	Dialog.createNonBlocking("Re-measure?");
		Dialog.addMessage("Analysis finished. Re-measure?");
		Dialog.addCheckbox("Analysis completed?", true);
	Dialog.show();
	reiterate = Dialog.getCheckbox();
}
print("Analysis terminated");