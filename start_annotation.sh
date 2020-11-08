#!/bin/bash
###############################################################################################################################################
### Annotation pipeline                                                                                                                     ### 
### Author: Alejandra Hernandez-Segura                                                                                                      ### 
### Organization: Rijksinstituut voor Volksgezondheid en Milieu (RIVM)                                                                      ### 
### Department: Infektieziekteonderzoek, Diagnostiek en Laboratorium Surveillance (IDS), Bacteriologie (BPD)                                ### 
### Date: 03-11-2020                                                                                                                        ### 
###                                                                                                                                         ### 
### Documentation: https://github.com/AleSR13/AMR_annotation.git                                                                            ### 
###                                                                                                                                         ### 
###                                                                                                                                         ### 
### Snakemake rules (in order of execution):                                                                                                ### 
###     1 Circlator        # correct the start of the chromosomes/plasmids if necessary                                                     ### 
###     2 PGAP             # Annotation using the NCBI tool, PGAP.                                                                          ### 
###     3 Prokka           # Annotation using Prokka and the PLSD database                                                                  ### 
###                                                                                                                                         ###
###############################################################################################################################################


# Load in necessary functions
set -o allexport
source bin/include/functions.sh
eval "$(parse_yaml config/config.yaml "configuration_")"
set +o allexport

UNIQUE_ID=$(bin/include/generate_id.sh)
SET_HOSTNAME=$(bin/include/gethostname.sh)

### Conda environment
PATH_MASTER_YAML="envs/master_env.yaml"
MASTER_NAME=$(head -n 1 ${PATH_MASTER_YAML} | cut -f2 -d ' ') # Extract Conda environment name as specified in yaml file

### Default values for parameters
INPUT_DIR="raw_data/"
OUTPUT_DIR="out/"
GENUS="NotProvided"
SPECIES="NotProvided"
METADATA_FILE="X"
PROTEIN_DB="/mnt/db/amr_annotation_db/refseq_plasmids/all_plasmid.nonredundant_proteins.fasta"
SNAKEMAKE_UNLOCK="FALSE"
CLEAN="FALSE"
HELP="FALSE"
SHEET_SUCCESS="FALSE"

### Parse the commandline arguments, if they are not part of the pipeline, they get send to Snakemake
POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -i|--input)
        INPUT_DIR="$2"
        shift # Next
        shift # Next
        ;;
        -o|--output)
        OUTPUT_DIR="$2"
        shift # Next
        shift # Next
        ;;
        --genus)
        GENUS="$2"
        shift
        shift
        ;;
        --species)
        SPECIES="$2"
        shift
        shift
        ;;
        --metadata)
        METADATA_FILE="$2"
        shift
        shift
        ;;
        -h|--help)
        HELP="TRUE"
        shift # Next
        ;;
        -sh|--snakemake-help)
        SNAKEMAKE_HELP="TRUE"
        shift # Next
        ;;
        --clean)
        CLEAN="TRUE"
        shift # Next
        ;;
        -y)
        SKIP_CONFIRMATION="TRUE"
        shift # Next
        ;;
        -u|--unlock)
        SNAKEMAKE_UNLOCK="TRUE"
        shift # Next
        ;;
        *) # Any other option
        POSITIONAL+=("$1") # save in array
        shift # Next
        ;;
    esac
done
set -- "${POSITIONAL[@]:-}" # Restores the positional arguments (i.e. without the case arguments above) which then can be called via `$@` or `$[0-9]` etc. These parameters are send to Snakemake.


### Print AMR_annotation pipeline help message
if [ "${HELP:-}" == "TRUE" ]; then
    line
    cat <<HELP_USAGE
AMR_annotation pipeline, built with Snakemake
  Usage: bash $0 -i <INPUT_DIR> <parameters>

Input:
  -i, --input [DIR]                 This is the folder containing your input fasta files.
                                    Default is raw_data/

  -o, --output [DIR]                This is the folder containing your output (results) files.
                                    Default is out/ 

  --genus [STR]                     Genus of the samples. Only one can be provided and it will be assumed to be the same one for all 
                                    samples. For example: "--genus Escherichia". Default "Not provided"

  --species [STR]                   Species of the sample (no genus included). Only one can be provided and it will be assumed to be 
                                    the same one for all samples. For example: "--species coli". Default "Not provided"

  --metadata [.csv]                 CSV file with at least 3 columns: "File_name", "Genus" and "Species". Where the "File_name" should 
                                    coincide EXACTLY (case sensitive) with the name of the fasta file of the sample. The genus and the
                                    species they should both be terms accepted in the TaxID system and one single word each. For example:
                                    mysample.fasta, Escherichia, coli.

  --proteins                        Path to protein database (fasta file with PROTEIN sequences) to be used for annotation with prokka. 
                                    Default is: /mnt/db/amr_annotation_db/plsdb/plsdb_proteins.fasta and contains the PLSDB database

Output (automatically generated):
  <output_dir>/                     Contains dir contains the results of every step of the pipeline.

  <output_dir>/log/                 Contains the log files for every step of the pipeline

  <output_dir>/log/drmaa			Contains the .out and .err files of every job sent to the grid/cluster.

  <output_dir>/log/results		    Contains the log files and parameters that the pipeline used for the current run


Parameters:
  -h, --help                        Print the help document.

  -sh, --snakemake-help             Print the snakemake help document.

  --clean (-y)                      Removes output (-y forces "Yes" on all prompts).

  -n, --dry-run                     Useful snakemake command that displays the steps to be performed without actually 
				                    executing them. Useful to spot any potential issues while running the pipeline.

  -u, --unlock                      Unlocks the working directory. A directory is locked when a run ends abruptly and 
				                    it prevents you from doing subsequent analyses on that directory until it gets unlocked.

  Other snakemake parameters	    Any other parameters will be passed to snakemake. Read snakemake help (-sh) to see
				                    the options.


HELP_USAGE
    exit 0
fi

### Remove all output
if [ "${CLEAN:-}" == "TRUE" ]; then
    bash bin/Clean
    exit 0
fi

###############################################################################################################
##### Installation block                                                                                  #####
###############################################################################################################

### Pre-flight check: Assess availability of required files, conda and master environment
if [ ! -e "${PATH_MASTER_YAML}" ]; then # If this yaml file does not exist, give error.
    line
    spacer
    echo -e "ERROR: Missing file \"${PATH_MASTER_YAML}\""
    exit 1
fi

if [[ $PATH != *${MASTER_NAME}* ]]; then # If the master environment is not in your path (i.e. it is not currently active), do...
    line
    spacer
    set +ue # Turn bash strict mode off because that breaks conda
    conda activate "${MASTER_NAME}" # Try to activate this env
    if [ ! $? -eq 0 ]; then # If exit statement is not 0, i.e. master conda env hasn't been installed yet, do...
        installer_intro
        if [ "${SKIP_CONFIRMATION}" = "TRUE" ]; then
            echo -e "\tInstalling master environment..." 
            conda env create -f ${PATH_MASTER_YAML} 
            conda activate "${MASTER_NAME}"
            echo -e "DONE"
        else
            while read -r -p "The master environment hasn't been installed yet, do you want to install this environment now? [y/n] " envanswer
            do
                envanswer=${envanswer,,}
                if [[ "${envanswer}" =~ ^(yes|y)$ ]]; then
                    echo -e "\tInstalling master environment..." 
                    conda env create -f ${PATH_MASTER_YAML}
                    conda activate "${MASTER_NAME}"
                    echo -e "DONE"
                    break
                elif [[ "${envanswer}" =~ ^(no|n)$ ]]; then
                    echo -e "The master environment is a requirement. Exiting because the AMR_annotation pipeline cannot continue without this environment"
                    exit 1
                else
                    echo -e "Please answer with 'yes' or 'no'"
                fi
            done
        fi
    fi
    set -ue # Turn bash strict mode on again
    echo -e "Succesfully activated master environment"
fi

###############################################################################################################
#####                          Snakemake-only parameters                                                  #####
###############################################################################################################

if [ "${SNAKEMAKE_UNLOCK}" == "TRUE" ]; then
    printf "\nUnlocking working directory...\n"
    snakemake --config out=$OUTPUT_DIR genus=$GENUS species=$SPECIES protein_db=$PROTEIN_DB --profile config --unlock ${@}
    printf "\nDone.\n"
    exit 0
fi


### Print Snakemake help
if [ "${SNAKEMAKE_HELP:-}" == "TRUE" ]; then
    line
    snakemake --help
    exit 0
fi

###############################################################################################################
#####                             Check input is correct                                                  #####
###############################################################################################################

if [ ! -d "${INPUT_DIR}" ]; then
    minispacer
    echo -e "The input directory specified (${INPUT_DIR}) does not exist"
    echo -e "Please specify an existing input directory"
    minispacer
    exit 1
fi

if [ $METADATA_FILE != "X" ]; then
    if [ ! -f $METADATA_FILE ]; then
        echo -e "The provided species file ${METADATA_FILE} does not exist. Please provide an existing file"
        exit 1
    fi
fi



### Generate sample sheet
if [  `find $INPUT_DIR -type f -name *.fasta | wc -l` -gt 0 ]; then
    minispacer
    echo -e "Files in input directory (${INPUT_DIR}) are present"
    echo -e "Generating sample sheet..."
    # Add genus and species info to sample_sheet
    if [ $METADATA_FILE != "X" ]; then
        python bin/generate_sample_sheet.py "${INPUT_DIR}" --metadata `realpath ${METADATA_FILE}` > sample_sheet.yaml
    else
        python bin/generate_sample_sheet.py "${INPUT_DIR}" > sample_sheet.yaml
    fi

    if [ $(wc -l sample_sheet.yaml | awk '{ print $1 }') -gt 2 ]; then
        SHEET_SUCCESS="TRUE"
    fi
else
    minispacer
    echo -e "The input directory you specified (${INPUT_DIR}) exists but is empty or does not contain the expected input files...\nPlease specify a directory with input-data."
    exit 0
fi

### Checker for succesfull creation of sample_sheet
if [ "${SHEET_SUCCESS}" == "TRUE" ]; then
    echo -e "Succesfully generated the sample sheet"
    echo -e "\nReady for start"
else
    echo -e "Couldn't find files in the input directory that ended up being in a .fasta format"
    echo -e "Please inspect the input directory (${INPUT_DIR}) and make sure the files are in .fasta format"
    exit 1
fi


###############################################################################################################
#####                             Run AMR_annotation pipeline                                             #####
###############################################################################################################

### Actual snakemake command with checkers for required files. N.B. here the UNIQUE_ID and SET_HOSTNAME variables are set!
if [ -e sample_sheet.yaml ]; then
    echo -e "Starting snakemake"
    set +ue #turn off bash strict mode because snakemake and conda can't work with it properly
    echo -e "pipeline_run:\n    identifier: ${UNIQUE_ID}" > config/variables.yaml
    echo -e "Server_host:\n    hostname: http://${SET_HOSTNAME}" >> config/variables.yaml
    eval $(parse_yaml config/variables.yaml "config_")
    snakemake --config out=$OUTPUT_DIR genus=$GENUS species=$SPECIES protein_db=$PROTEIN_DB --profile config \
        --drmaa " -q bio -n {threads} -R \"span[hosts=1]\"" --drmaa-log-dir ${OUTPUT_DIR}/log/drmaa ${@}
    if [ -d ${OUTPUT_DIR}/pgap_1 ]; then
        rm -r ${OUTPUT_DIR}/pgap/*_1
    fi
    if [ -f tbl2asn ]; then
        rm tbl2asn
    fi
    echo -e "AMR_annotation pipeline run complete"
    set -ue #turn bash strict mode back on
else
    echo -e "Sample_sheet.yaml could not be found"
    echo -e "This also means that the pipeline was unable to generate a new sample sheet for you"
    echo -e "Please inspect the input directory (${INPUT_DIR}) and make sure the right files are present"
    exit 1
fi

exit 0 