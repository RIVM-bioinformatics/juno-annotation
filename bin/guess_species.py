import argparse
import yaml
import glob
import pandas as pd
import os

# Load dictionary with translation table (abbreviations versus genus and species)
translation_tbl = {}
with open("files/dictionary_samples.yaml") as translation_yaml:
    translation_tbl = yaml.safe_load(translation_yaml)

def find_abbreviation(file_name, abbreviation):
    if file_name.__contains__(abbreviation):
        return translation_tbl[abbreviation]

def main(args):
    # Get file names 
    file_species = pd.DataFrame(glob.glob(args.dir+"/*.fasta"), columns=["File_name"])
    file_species["genus"] = ""
    file_species["species"] = ""
    file_species["File_name"] = file_species["File_name"].apply(os.path.basename)
    # File names to genus/species
    for file, abbr in [(file, abbr) for file in file_species["File_name"].tolist() for abbr in list(translation_tbl.keys())]:
        if find_abbreviation(file, abbr) is not None :
            dict_sample = find_abbreviation(file, abbr)
            file_species.loc[file_species["File_name"] == file, "genus"] = dict_sample["genus"]
            file_species.loc[file_species["File_name"] == file, "species"] = dict_sample["species"]
    if not file_species.empty:
        file_species.to_csv("metadata.csv", index = False)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("dir", type=str, 
                       help="Path to input directory with fastq files")
    main(parser.parse_args())