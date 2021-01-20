"""
AMR_annotation pipeline
Authors: Alejandra Hernandez-Segura
Organization: Rijksinstituut voor Volksgezondheid en Milieu (RIVM)
Department: Infektieziekteonderzoek, Diagnostiek en Laboratorium Surveillance (IDS), Bacteriologie (BPD)
Date: 03-11-2020

Documentation: https://github.com/AleSR13/AMR_annotation.git


Snakemake rules (in order of execution):
    1 Circlator        # correct the start of the chromosomes/plasmids if necessary  
    2 PGAP             # Annotation using the NCBI tool, PGAP. 
    3 Prokka           # Annotation using Prokka and the PLSD database 

"""

#################################################################################
#####                            DEPENDENCIES                               #####
#################################################################################

import yaml
import os

#################################################################################
##### Load samplesheet, load species file and define output directory         #####
#################################################################################

# Config file
configfile: "config/pipeline_parameters.yaml"

# SAMPLES is a dict with sample in the form sample > file. E.g.: SAMPLES["sample_1"]["file"] = "sample_1.fasta"
SAMPLES = {}
with open(config["sample_sheet"]) as sample_sheet_file:
    SAMPLES = yaml.safe_load(sample_sheet_file) 

# OUT defines output directory for most rules.
OUT = os.path.abspath(config["out"])
GENUS_ALL = config["genus"]
SPECIES_ALL = config["species"]
PROTEIN_DB = config["protein_db"]

# Assign genus and species for the samples in which it was not identified
for sample in SAMPLES:
    # Assign genus if non-existing
    try:
        SAMPLES[sample]["genus"]
    except KeyError:
        SAMPLES[sample]["genus"] = GENUS_ALL
    # Assign species if non-existing
    try:
        SAMPLES[sample]["Species"]
    except KeyError:
        SAMPLES[sample]["Species"] = GENUS_ALL

#@################################################################################
#@#### 				            Processes                                    #####
#@################################################################################

    #############################################################################
    #####          Fix starting point of chromosome and plasmids            #####
    #############################################################################
include: "bin/rules/filter_contigs.smk"
include: "bin/rules/circlator.smk"
    #############################################################################
    #####                       Annotation                                  #####
    #############################################################################
include: "bin/rules/update_tbl2asn.smk"
include: "bin/rules/prokka.smk"

    #############################################################################
    #####           Fix GenBank file and fine-tune results                  #####
    #############################################################################
#include: "bin/rules/fix_genbank.smk"

#@################################################################################
#@#### The `onstart` checker codeblock                                       #####
#@################################################################################

onstart:
    try:
        print("Checking if all specified files are accessible...")
        important_files = [ config["sample_sheet"] ]
        for filename in important_files:
            if not os.path.exists(filename):
                raise FileNotFoundError(filename)
    except FileNotFoundError as e:
        print("This file is not available or accessible: %s" % e)
        sys.exit(1)
    else:
        print("\tAll specified files are present!")
    shell("""
        mkdir -p {OUT}/results
        echo -e "\nLogging pipeline settings..."
        echo -e "\tGenerating methodological hash (fingerprint)..."
        echo -e "This is the link to the code used for this analysis:\thttps://github.com/AleSR13/AMR_annotation/tree/$(git log -n 1 --pretty=format:"%H")" > '{OUT}/results/log_git.txt'
        echo -e "This code with unique fingerprint $(git log -n1 --pretty=format:"%H") was committed by $(git log -n1 --pretty=format:"%an <%ae>") at $(git log -n1 --pretty=format:"%ad")" >> '{OUT}/results/log_git.txt'
        echo -e "\tGenerating full software list of current Conda environment (\"amr_master\")..."
        conda list > '{OUT}/results/log_conda.txt'
        echo -e "\tGenerating config file log..."
        rm -f '{OUT}/results/log_config.txt'
        for file in config/*.yaml
        do
            echo -e "\n==> Contents of file \"${{file}}\": <==" >> '{OUT}/results/log_config.txt'
            cat ${{file}} >> '{OUT}/results/log_config.txt'
            echo -e "\n\n" >> '{OUT}/results/log_config.txt'
        done
        echo -e "\n==> Contents of sample sheet: <==" >> '{OUT}/results/log_config.txt'
            cat sample_sheet.yaml >> '{OUT}/results/log_config.txt'
            echo -e "\n\n" >> '{OUT}/results/log_config.txt'
        echo -e "\n==> Extra parameters given while calling the pipeline (they overwrite any defaults): \n   \
            Output directory: {OUT} \n   \
            Genus used as default (if not provided in metadata): {GENUS_ALL} \n   \
            Species used as default (if not provided in metadata): {SPECIES_ALL} \n   \
            Protein database: {PROTEIN_DB}\n\n" >> '{OUT}/results/log_config.txt'
    """)

#@################################################################################
#@#### These are the conditional cleanup rules                               #####
#@################################################################################

onerror:
    print("An error occurred")
    #shell("rm -r {OUT}/pgap_1")


onsuccess:
    shell("""
        echo -e "Removing temporary files..."
        find {OUT} -type d -empty -delete
        echo -e "\tGenerating HTML index of log files..."
        echo -e "\tGenerating Snakemake report..."
        snakemake --profile config --config out="{OUT}" genus="{GENUS_ALL}" species={SPECIES_ALL} --unlock
        snakemake --profile config --config out="{OUT}" genus="{GENUS_ALL}" species={SPECIES_ALL} --report '{OUT}/results/snakemake_report.html'
        echo -e "Finished"
    """)


#################################################################################
##### Specify final output:                                                 #####
#################################################################################

localrules:
    all,
    filter_contigs,
    update_tbl2asn


rule all:
    input:
        expand(OUT + "/circlator/{sample}/{sample}.fasta", sample = SAMPLES),
        expand(OUT + "/prokka/{sample}/{sample}.gbk", sample = SAMPLES)
