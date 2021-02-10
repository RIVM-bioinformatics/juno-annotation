# Annotation pipeline

This pipeline takes assemblies (.fasta) as input and performs gene annotation. It should be able to annotate bacterial genomes and bacterial plasmids. The pipeline follows these steps:

1. Filtering contigs with more than 200bp. This step is necessary for downstream tools to run properly and, in general, small contigs are often filtered to reduce the noise of possible contamination. Besides, these small contigs often do not contain much valuable information.
2. Finding the start of the chromosome ( [Circlator](https://github.com/sanger-pathogens/circlator) ). Although in most cases, the chromosome is already circularized after the assembly, in the cases in which that was not possible, this step might help. The start of the chromosome will be set at the beginning of the _dnaA_ gene. For the plasmids or other smaller contigs, the start of a predicted gene near its center is used. 
3. Annotation using two different tools: [Prokka](https://github.com/tseemann/prokka) and [PGAP](https://github.com/ncbi/pgap). Prokka is a fast program for prokaryotic genome annotation. We enriched the databases that Prokka relies on with plasmid genes as found in RefSeq. PGAP is the annotation tool from the NCBI. Although PGAP often finds more annotated genes than Prokka, it is significantly slower (30 min versus more than 3 hours). 

### Requirements and preparation

This handbook assumes that you are working at the “bioinformatica” environment at the RIVM. It is possible to run the pipeline in other settings and even on your laptop but you need extra steps that will not be enlisted here.  

- Placing of the data: Your data should all be placed in one single folder (no subfolders).  

- Make sure that your files have the right format: they must have a fasta extension (.fasta). 

- The pipeline needs to know the Genus and Species of each input fasta file. There are three ways to do this (see the section Run the pipeline for more details on how to do this and the recognized abbreviations): 
    + The pipeline can guess this information from the file name provided the appropriate abbreviations are used within the name. 
    + You can provide a metadata file (.csv) that should contain at least three columns: "File_name", "Genus" and "Species" (mind the capital letters). The File name is case sensitive, so the names of the files (without the full path) should coincide EXACTLY with your input fasta files. The genus and species should be recognized as an official [TaxID](https://www.ncbi.nlm.nih.gov/taxonomy). You MUST write the genus and the species in the appropriate column, never together in one column. This option cannot be combined with the first one. This means that if you decide to "guess" the genus and species from the file name, the provided metadata file will be ignored.
    + You can provide the genus and species directly when calling the pipeline. The genus and species should be recognized as an official [TaxID](https://www.ncbi.nlm.nih.gov/taxonomy). YOU CAN ONLY PROVIDE ONE GENUS AND ONE SPECIES and this will be used for all samples. You can combine this option with one of the two above. This means that if you have multiple samples but some of them are not enlisted in your metadata file, they will instead inherit the genus and species from the information provided directly when calling the pipeline. If all the files were enlisted in the metadata, this option will be ignored.

### Download the pipeline  
**YOU ONLY NEED TO RUN THIS SECTION THE FIRST TIME THAT YOU USE THE PIPELINE OR EVERY TIME YOU WANT TO UPDATE IT**

1. Open a terminal.  
2. Go to the location where you want to download the pipeline using the command ‘cd’. For instance:  

```
cd /my_laptop/<my_folder>/
```

3. Download the pipeline using the `git clone` command  

```
git clone https://github.com/AleSR13/AMR_annotation.git
```


### Start the analysis. Basics

1. Open the terminal.  
2. Enter the folder of the pipeline using:  

```
cd /my_laptop/<my_folder>/AMR_annotation
```

3. Run the pipeline  

If all your samples have the same genus and species, for instance, _Klebsiella pneumoniae_, you run it like this:

```
bash start_annotation.sh -i /my_laptop/<my_folder>/<my_data>/ --genus Klebsiella --species pneumoniae
```
* Note that the genus and species should be ONE word. Do not put genus and species together!

If your samples do not have all the same genus, you can make a metadata file. This file should be a .csv file with at least these columns and information: 

|File_name          |Genus          |Species    |
|:------------------|:--------------|:----------|
|sample1_Kpn.fasta  |Klebsiella     |pneumoniae |
|sample2Pae2.fasta  |Pseudomonas    |aeruginosa |
|sample3Sau_1.fasta |Staphylococcus |aureus     |

* Note that the name of the columns should be EXACTLY the same than in this example, including the underscores and the capital letters.

You would then call the pipeline like this:

```
bash start_annotation.sh -i /my_laptop/<my_folder>/<my_data>/ --metadata path/to/metadata.csv
```

Alternatively, if your input files have one of the following abbreviations somewhere in the data, the genus and species may be automatically guessed from the file name:

|Abbreviation |Genus          |Species      |
|:------------|:--------------|:------------|
|Cam          |Citrobacter    |amalonaticus |
|Cbr          |Citrobacter    |braakii      |
|Cfr          |Citrobacter    |freundii     |
|Cse          |Citrobacter    |sedlakii     |
|Cwe          |Citrobacter    |werkmanii    |
|Ebu          |Enterobacter   |bugandensis  |
|Eca          |Enterobacter   |cancerogenus |
|Ecl          |Enterobacter   |cloacae      |
|Eco          |Escherichia    |coli         |
|Exi          |Enterobacter   |cloacae      |
|Kae          |Klebsiella     |aerogenes    |
|Kox          |Klebsiella     |oxytoca      |
|Kpn          |Klebsiella     |pneumoniae   |
|Mmo          |Morganella     |morganii     |
|Pae          |Pseudomonas    |aeruginosa   |
|Pmi          |Proteus        |mirabilis    |
|Rpl          |Raoultella     |planticola   |
|Sar          |Staphylococcus |argenteus    |
|Sau          |Staphylococcus |aureus       |
|Sma          |Serratia       |marcescens   |

Then you would call the pipeline like this:

```{bash}
bash start_annotation.sh -i /my_laptop/<my_folder>/<my_data>/ --make-metadata
```

The pipeline should start running by itself and give you instructions. The first time you run the pipeline, the preparation might take longer than expected and it will need more input from you. Most of the text informs of the progress but often you are required to give input. Try to read what is appearing on the screen and if you get asked to give a permission, please do.  

The first thing that may happen is that you may get a message saying that:

```
The master environment hasn't been installed yet, do you want to install this environment now? [y/n]
```

You just have to answer with a `y` as prompted. The installation will start by itself. In the next steps, many messages will appear on your screen, they are likely to be installation processes. Be patient! The installation may take some time. Once the installation is over, the pipeline should start running. 

### Output 

A folder called `out/`, inside the folder of the pipeline, will be created. This folder will contain all the results and logging files of your analysis. There will be one folder per tool (circlator, filtered_contigs, pgap and prokka). Please refer to the manuals of every tool to interpret the results. Your main result will be two genebank (.gbk) files per sample that you can find inside the subfolders `out/prokka`. 

There are also two important subfolders generated by this pipeline:

- The `out/log/` folder contains information about every step performed for every sample. There you can find error messages or some information of what happened during each step. The messages are not always easy to interpret, but they often have clues on why a job/analysis failed. Sometimes the log files for each tool (and sample) are empty because either, there were no problems or messages generated on the run or because the problem lies before the job/analysis was even started. In the later case, you may want to look at the subfolder `out/log/drmaa/` where you can find logging files of any job performed by the pipeline. Here it is not always easy to find the job you are looking for, but do know that they are there and they can be accessed if necessary.

- The `out/results/` folder contains 4 very important files for traceability of your samples. The `log_conda.txt file` contains information about the software that was necessary and that was contained in your environment. This means basically the software that would be needed to reproduce the same circumstances in which the pipeline was run and how it can be reproduced. The `log_config.txt` file is even more informative. It enlists all the parameters used to run the pipeline. In case months laters you forgot how you got the results you did or you just want to know some details about the analyses, they are all stored there. The `log_git.txt` has information about the repository or the code that was downloaded. It tells you exactly how it was donwloaded so you can reproduce it at a later timepoint. Finally, the `snakemake_report.html` has a nice overview of the different steps that were performed with your samples, when were they performed, which output was produced and which software was used, as well as some statistics on how the run went. 

*Note:* If you want your output to be stored in a folder with a different name or location, you can use the option `-o` (from output) 

```
bash start_annotation.sh -i /my_laptop/<my_folder>/<my_data>/ -o /mnt/scratch_dir/<my_folder>/<my_results>/
```
