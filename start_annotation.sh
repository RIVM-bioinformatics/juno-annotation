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

# Fail if error
set -eu

# Load in necessary functions
set -o allexport
source bin/include/functions.sh
eval "$(parse_yaml config/config.yaml "configuration_")"
set +o allexport
#set -x # Debug mode if necessary

UNIQUE_ID=$(bin/include/generate_id.sh)
SET_HOSTNAME=$(bin/include/gethostname.sh)

### Conda environment
PATH_MASTER_YAML="envs/master_env.yaml"
MASTER_NAME=$(head -n 1 ${PATH_MASTER_YAML} | cut -f2 -d ' ') # Extract Conda environment name as specified in yaml file

### Default values for parameters
INPUT_DIR="raw_data"
OUTPUT_DIR="out"
GENUS="NotProvided"
SPECIES="NotProvided"
MAKE_METADATA="FALSE"
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
        INPUT_DIR="${2%/}"
        shift # Next
        shift # Next
        ;;
        -o|--output)
        OUTPUT_DIR="${2%/}"
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
        --proteins)
        PROTEIN_DB="$2"
        shift
        shift
        ;;
        --make-metadata)
        MAKE_METADATA="TRUE"
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
    cat bin/include/help.txt
    exit 0
fi

### Remove all output
if [ "${CLEAN:-}" == "TRUE" ]; then
    export OUTPUT_DIR=${OUTPUT_DIR}
    bash bin/include/Clean
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


## Activate mamba
set +ue # Turn bash strict mode off because that breaks conda
conda env update -f envs/mamba.yaml
source activate mamba

if [[ $PATH != *${MASTER_NAME}* ]]; then # If the master environment is not in your path (i.e. it is not currently active), do...
    line
    spacer
    source activate "${MASTER_NAME}" # Try to activate this env
    if [ ! $? -eq 0 ]; then # If exit statement is not 0, i.e. master conda env hasn't been installed yet, do...
        if [ "${SKIP_CONFIRMATION}" = "TRUE" ]; then
            echo -e "\tInstalling master environment..." 
            mamba env update -f ${PATH_MASTER_YAML} 
            source activate "${MASTER_NAME}"
            echo -e "DONE"
        else
            while read -r -p "The master environment hasn't been installed yet, do you want to install this environment now? [y/n] " envanswer
            do
                envanswer=${envanswer,,}
                if [[ "${envanswer}" =~ ^(yes|y)$ ]]; then
                    echo -e "\tInstalling master environment..." 
                    mamba env update -f ${PATH_MASTER_YAML}
                    source activate "${MASTER_NAME}"
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
    echo -e "Succesfully activated master environment"
fi
set -ue # Turn bash strict mode on again

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

# Make metadata if asked
if [ $MAKE_METADATA == "TRUE" ]; then
    echo -e "\n\nMaking metadata..."
    rm -f "metadata.csv"
    python bin/guess_species.py $INPUT_DIR
    METADATA_FILE="./metadata.csv"
    echo -e "\n\nSuccessfully created metadata.csv file"
fi

# Check provided metadata exists
if [ $METADATA_FILE != "X" ]; then
    if [ ! -f $METADATA_FILE ]; then
        minispacer
        echo -e "The provided species file ${METADATA_FILE} does not exist. Please provide an existing file"
        echo -e "If you used the option --make-metadata, please check that all the fasta files contain the .fasta
        extension and that the file names have the right abbreviations for genus/species"
        minispacer
        exit 1
    fi
fi

if [ "$GENUS" == "NotProvided" ] && [ "$MAKE_METADATA" == "FALSE" ] && [ "$METADATA_FILE" == "X" ]; then
    echo "ERROR! You need to provide either the --genus, a --metadata file or choose the --make-metadata option (if your files have the right abbreviations for it)."
    exit 1
fi

if [ -f ${PROTEIN_DB} ]; then
    if [[ ! "${PROTEIN_DB}" =~ "fasta"$ ]] && [[ ! "${PROTEIN_DB}" =~ "gbk"$ ]]; then
        minispacer
        echo -e "${PROTEIN_DB} file not accepted. Only .fasta or .gbk files are accepted in --proteins. Please provide a file with a supported format."
        minispacer
        exit 1
    fi
else
    minispacer
    echo -e "The provided database file ${PROTEIN_DB} does not exist. Please provide an existing file"
    minispacer
    exit 1
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
    minispacer
    exit 1
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
    echo -e "start_annotation call:\n" > config/amr_annotation_call.txt
    echo -e "snakemake --config out=$OUTPUT_DIR genus=$GENUS species=$SPECIES protein_db=$PROTEIN_DB --profile config \
        --drmaa ' -q bio -n {threads} -R \'span[hosts=1]\'' --drmaa-log-dir ${OUTPUT_DIR}/log/drmaa ${@}" >> config/amr_annotation_call.txt
    echo -e "AMR_annotation pipeline run complete"
    set -ue #turn bash strict mode back on
else
    echo -e "Sample_sheet.yaml could not be found"
    echo -e "This also means that the pipeline was unable to generate a new sample sheet for you"
    echo -e "Please inspect the input directory (${INPUT_DIR}) and make sure the right files are present"
    exit 1
fi

exit 0 
