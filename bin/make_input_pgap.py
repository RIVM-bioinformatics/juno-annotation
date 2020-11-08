import argparse
import re
import yaml
import os

def main(args):
    input_yaml = {}
    with open("files/example_input.yaml") as example_input_file:
        input_yaml = yaml.safe_load(example_input_file) 

    submol_yaml = {}
    with open("files/example_submol.yaml") as example_submol_file:
        submol_yaml = yaml.safe_load(example_submol_file) 

    # Rewrite the name of input files
    input_yaml["fasta"]["location"] = str(args.fasta_file)
    input_yaml["submol"]["location"] = os.path.basename(str(args.submol_file))

    with open(str(args.input_file), 'w') as file:
        documents = yaml.dump(input_yaml, file, default_flow_style=False)
    
    # Add genus and species if provided
    if (str(args.genus) != "NotProvided" and str(args.genus) != "nan") :
        if (str(args.species) != "NotProvided" and str(args.species) != "nan") :
            submol_yaml["organism"]["genus_species"] = str(args.genus).lower().capitalize() + " " + str(args.species).lower()
        else:
            submol_yaml["organism"]["genus_species"] = str(args.genus).lower().capitalize()
    
    with open(str(args.submol_file), 'w') as file:
        documents = yaml.dump(submol_yaml, file, default_flow_style=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--fasta_file", type=str, 
                       help="Path to fasta file for which an input and submol files to be used as pgap input will be generated")
    parser.add_argument("--genus", type=str, 
                       help="Genus of the sample")
    parser.add_argument("--species", type=str, 
                       help="Species of the sample")
    parser.add_argument("--input_file", type=str, 
                       help="Path and file name of the <sample_name>_input.yaml file to be generated")
    parser.add_argument("--submol_file", type=str, 
                       help="Path and file name of the <sample_name>_submol.yaml file to be generated")
    main(parser.parse_args())
